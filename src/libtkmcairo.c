/*
 * libtkmcairo.c
 * tkmcairo -- Cairo 2D graphics library for Tcl
 *
 * Version: 0.1
 * Lizenz:  BSD
 *
 * No dependency on Tk, X11, or Wayland.
 * Runs in tclsh. Output: PNG, PDF, SVG, PS/EPS.
 *
 * Tcl API:
 *   tkmcairo create width height ?-mode raster|vector? -> handle
 *   tkmcairo destroy handle
 *   tkmcairo clear  handle r g b ?a?
 *   tkmcairo save   handle filename          (.png .pdf .svg .ps .eps)
 *   tkmcairo size   handle                   -> {w h}
 *   tkmcairo todata handle                   -> bytearray ARGB32
 *
 *   tkmcairo rect   handle x y w h opts
 *   tkmcairo line   handle x1 y1 x2 y2 opts
 *   tkmcairo circle handle cx cy r opts
 *   tkmcairo ellipse handle cx cy rx ry opts
 *   tkmcairo arc    handle cx cy r start end opts
 *   tkmcairo poly   handle x1 y1 x2 y2 ... opts
 *   tkmcairo path   handle svgdata opts      (M L C Q A Z)
 *   tkmcairo text   handle x y string opts
 *
 *   tkmcairo font_measure handle string font -> {width height ascent descent}
 *   tkmcairo transform handle -translate x y | -scale sx sy | -rotate deg | -reset
 *
 *   tkmcairo gradient_linear handle name x1 y1 x2 y2 stops
 *   tkmcairo gradient_radial handle name cx cy r stops
 *   (stops: {{offset r g b a} ...})
 *
 * Options (as key/value pairs after coordinates):
 *   -fill    {r g b ?a?}     Fill color
 *   -stroke  {r g b ?a?}     Stroke color
 *   -width   n               Line width
 *   -dash    {on off ...}    Dash pattern
 *   -font    "Family Bold Italic Size"
 *   -color   {r g b ?a?}     Text color
 *   -alpha   0.0..1.0        Global alpha
 *   -anchor  nw|n|ne|w|center|e|sw|s|se
 *   -radius  r               Corner radius for rect
 *   -fillname gradname       Gradient as fill
 *   -linecap  butt|round|square
 *   -linejoin miter|round|bevel
 */

#include <tcl.h>
#include <cairo/cairo.h>
#include <cairo/cairo-pdf.h>
#include <cairo/cairo-svg.h>
#include <cairo/cairo-ps.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>   /* strcasecmp */
#include <stdio.h>
#include <math.h>
#include <ctype.h>

/* Tcl_Size Kompatibilitaet: Tcl 8.6 hat kein Tcl_Size (erst ab 8.7/9.0)
 * In Tcl 9.0 ist Tcl_Size = ptrdiff_t (64-bit sauber).
 * Der Shim macht libtkmcairo.c auf 8.6 und 9.0 kompilierbar. */
#if !defined(Tcl_Size)
#  if defined(TCL_SIZE_MAX)
     /* Tcl 9.0+: Tcl_Size bereits via tcl.h definiert */
#  else
     typedef int Tcl_Size;
#    define TCL_SIZE_MAX INT_MAX
#  endif
#endif


#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

/* ================================================================== */
/* Error-checking macros for Tcl_Get* functions                       */
/* ================================================================== */

#define GET_DOUBLE(interp, obj, var) \
    do { if (Tcl_GetDoubleFromObj((interp),(obj),&(var)) != TCL_OK) \
             return TCL_ERROR; } while(0)

#define GET_INT(interp, obj, var) \
    do { if (Tcl_GetIntFromObj((interp),(obj),&(var)) != TCL_OK) \
             return TCL_ERROR; } while(0)

#define GET_LIST(interp, obj, np, ep) \
    do { if (Tcl_ListObjGetElements((interp),(obj),(np),(ep)) != TCL_OK) \
             return TCL_ERROR; } while(0)


/* ================================================================== */
/* Gradient storage                                                   */
/* ================================================================== */

#define MAX_GRAD 64

typedef struct {
    char            name[64];
    cairo_pattern_t *pattern;
} Gradient;

/* ================================================================== */
/* Context                                                             */
/* ================================================================== */

#define MAX_CTX 64

typedef struct {
    int              id;
    int              width;
    int              height;
    int              vector;        /* 0=raster 1=recording */
    cairo_surface_t *surface;
    cairo_surface_t *rec;           /* recording surface (vector) */
    cairo_t         *cr;
    unsigned char   *data;          /* raster pixel data */
    Gradient         grads[MAX_GRAD];
    int              ngrads;
} CairoCtx;

static CairoCtx *g_ctx[MAX_CTX] = {0};
static int        g_next_id = 1;

static CairoCtx *ctx_find(int id) {
    for (int i = 0; i < MAX_CTX; i++)
        if (g_ctx[i] && g_ctx[i]->id == id) return g_ctx[i];
    return NULL;
}
static int ctx_store(CairoCtx *c) {
    for (int i = 0; i < MAX_CTX; i++)
        if (!g_ctx[i]) { g_ctx[i] = c; return 1; }
    return 0;
}
static void ctx_remove(int id) {
    for (int i = 0; i < MAX_CTX; i++)
        if (g_ctx[i] && g_ctx[i]->id == id) { g_ctx[i] = NULL; return; }
}

/* ================================================================== */
/* Color parser: {r g b} or {r g b a}                                */
/* ================================================================== */

static int parse_color(Tcl_Interp *interp, Tcl_Obj *obj,
    double *r, double *g, double *b, double *a)
{
    Tcl_Size n; Tcl_Obj **e;
    if (Tcl_ListObjGetElements(interp, obj, &n, &e) != TCL_OK) return 0;
    if (n < 3) {
        Tcl_SetResult(interp, "color must be {r g b} or {r g b a}", TCL_STATIC);
        return 0;
    }
    if (Tcl_GetDoubleFromObj(interp, e[0], r) != TCL_OK) return 0;
    if (Tcl_GetDoubleFromObj(interp, e[1], g) != TCL_OK) return 0;
    if (Tcl_GetDoubleFromObj(interp, e[2], b) != TCL_OK) return 0;
    *a = 1.0;
    if (n >= 4 && Tcl_GetDoubleFromObj(interp, e[3], a) != TCL_OK) return 0;
    return 1;
}

/* ================================================================== */
/* Font parser: "Family Bold Italic Size"                             */
/* ================================================================== */

static void parse_font(const char *spec,
    char *family, size_t fsz,
    cairo_font_weight_t *weight,
    cairo_font_slant_t  *slant,
    double *size)
{
    char buf[128]; snprintf(buf, sizeof(buf), "%s", spec);
    *weight = CAIRO_FONT_WEIGHT_NORMAL;
    *slant  = CAIRO_FONT_SLANT_NORMAL;
    *size   = 14.0;

    /* Letzte Zahl = size */
    char *sp = strrchr(buf, ' ');
    if (sp) { *size = atof(sp+1); *sp = '\0'; }

    if (strstr(buf, "Bold"))   { *weight = CAIRO_FONT_WEIGHT_BOLD; }
    if (strstr(buf, "Italic")) { *slant  = CAIRO_FONT_SLANT_ITALIC; }
    if (strstr(buf, "Oblique")){ *slant  = CAIRO_FONT_SLANT_OBLIQUE; }

    /* Remove style words */
    char *p;
    while ((p = strstr(buf, "Bold"))   != NULL) memset(p, ' ', 4);
    while ((p = strstr(buf, "Italic")) != NULL) memset(p, ' ', 6);
    while ((p = strstr(buf, "Oblique"))!= NULL) memset(p, ' ', 7);

    /* Trim */
    int l = (int)strlen(buf);
    while (l > 0 && (buf[l-1] == ' ' || buf[l-1] == '\t')) buf[--l] = '\0';
    char *s = buf; while (*s == ' ' || *s == '\t') s++;
    if (*s) snprintf(family, fsz, "%s", s);
    else    snprintf(family, fsz, "Sans");
}

/* ================================================================== */
/* Options                                                            */
/* ================================================================== */

typedef struct {
    double  fill_r, fill_g, fill_b, fill_a; int has_fill;
    double  stroke_r, stroke_g, stroke_b, stroke_a; int has_stroke;
    double  color_r, color_g, color_b, color_a; int has_color;
    double  line_width;
    double  alpha;
    double  radius;        /* for -radius (rounded rect) */
    char    font[128];
    char    anchor[16];
    char    fillname[64];  /* Gradient-Name */
    int     has_fillname;
    double  dash[16]; int ndash;
    int     linecap;   /* 0=butt 1=round 2=square */
    int     linejoin;  /* 0=miter 1=round 2=bevel */
} DrawOpts;

static void opts_defaults(DrawOpts *o) {
    o->fill_r=1; o->fill_g=1; o->fill_b=1; o->fill_a=1; o->has_fill=0;
    o->stroke_r=0; o->stroke_g=0; o->stroke_b=0; o->stroke_a=1; o->has_stroke=0;
    o->color_r=1; o->color_g=1; o->color_b=1; o->color_a=1; o->has_color=0;
    o->line_width=1.5; o->alpha=1.0; o->radius=0.0;
    strncpy(o->font, "Sans 14", sizeof(o->font)-1);
    strncpy(o->anchor, "sw", sizeof(o->anchor)-1);
    o->has_fillname=0; o->fillname[0]='\0';
    o->ndash=0; o->linecap=0; o->linejoin=0;
}

static int parse_opts(Tcl_Interp *interp, int objc,
    Tcl_Obj *const objv[], int start, DrawOpts *o)
{
    opts_defaults(o);
    /* Fix: ungerade Optionsliste -> Fehler (Option ohne Wert) */
    if ((objc - start) % 2 != 0) {
        Tcl_SetResult(interp, "option without value (odd number of option arguments)", TCL_STATIC);
        return 0;
    }
    for (int i = start; i+1 < objc; i += 2) {
        const char *k = Tcl_GetString(objv[i]);
        Tcl_Obj    *v = objv[i+1];
        if      (!strcmp(k,"-fill")) {
            if (!parse_color(interp,v,&o->fill_r,&o->fill_g,&o->fill_b,&o->fill_a)) return 0;
            o->has_fill = 1;
        }
        else if (!strcmp(k,"-stroke")) {
            if (!parse_color(interp,v,&o->stroke_r,&o->stroke_g,&o->stroke_b,&o->stroke_a)) return 0;
            o->has_stroke = 1;
        }
        else if (!strcmp(k,"-color")) {
            if (!parse_color(interp,v,&o->color_r,&o->color_g,&o->color_b,&o->color_a)) return 0;
            o->has_color = 1;
        }
        else if (!strcmp(k,"-width"))   { if (Tcl_GetDoubleFromObj(interp,v,&o->line_width) != TCL_OK) return 0; }
        else if (!strcmp(k,"-font"))  {
            strncpy(o->font,  Tcl_GetString(v),sizeof(o->font)-1);
            o->font[sizeof(o->font)-1] = '\0';
        }
        else if (!strcmp(k,"-anchor")) {
            strncpy(o->anchor,Tcl_GetString(v),sizeof(o->anchor)-1);
            o->anchor[sizeof(o->anchor)-1] = '\0';
        }
        else if (!strcmp(k,"-alpha")) {
            if (Tcl_GetDoubleFromObj(interp,v,&o->alpha) != TCL_OK) return 0;
            if (o->alpha < 0.0 || o->alpha > 1.0) {
                Tcl_SetResult(interp, "-alpha must be 0.0..1.0", TCL_STATIC);
                return 0;
            }
        }
        else if (!strcmp(k,"-radius"))  { if (Tcl_GetDoubleFromObj(interp,v,&o->radius) != TCL_OK) return 0; }
        else if (!strcmp(k,"-fillname")) {
            strncpy(o->fillname,Tcl_GetString(v),sizeof(o->fillname)-1);
            o->fillname[sizeof(o->fillname)-1] = '\0';
            o->has_fillname=1;
        }
                else if (!strcmp(k,"-linecap")) {
            const char *s=Tcl_GetString(v);
            if     (!strcmp(s,"butt"))   o->linecap=0;
            else if(!strcmp(s,"round"))  o->linecap=1;
            else if(!strcmp(s,"square")) o->linecap=2;
            else {
                Tcl_AppendResult(interp,"invalid -linecap: ",s," (butt|round|square)",NULL);
                return 0;
            }
        }
        else if (!strcmp(k,"-linejoin")) {
            const char *s=Tcl_GetString(v);
            if     (!strcmp(s,"miter")) o->linejoin=0;
            else if(!strcmp(s,"round")) o->linejoin=1;
            else if(!strcmp(s,"bevel")) o->linejoin=2;
            else {
                Tcl_AppendResult(interp,"invalid -linejoin: ",s," (miter|round|bevel)",NULL);
                return 0;
            }
        }
        else if (!strcmp(k,"-dash")) {
            Tcl_Size n; Tcl_Obj **e;
            if (Tcl_ListObjGetElements(interp,v,&n,&e)==TCL_OK) {
                o->ndash = (int)(n < 16 ? n : 16);
                for (int j=0; j<o->ndash; j++) {
                    if (Tcl_GetDoubleFromObj(interp,e[j],&o->dash[j]) != TCL_OK)
                        o->ndash = j;  /* truncate on error */
                }
            }
        }
        /* Fix: unbekannte Option -> TCL_ERROR */
        else {
            Tcl_AppendResult(interp, "unknown option \"", k, "\"", NULL);
            return 0;
        }
    }
    return 1;
}

/* ================================================================== */
/* Drawing helpers                                                       */
/* ================================================================== */

static void apply_stroke_opts(cairo_t *cr, DrawOpts *o) {
    cairo_set_line_width(cr, o->line_width);
    cairo_set_line_cap(cr,  (cairo_line_cap_t)o->linecap);
    cairo_set_line_join(cr, (cairo_line_join_t)o->linejoin);
    if (o->ndash > 0)
        cairo_set_dash(cr, o->dash, o->ndash, 0.0);
    else
        cairo_set_dash(cr, NULL, 0, 0.0);
}

static cairo_pattern_t *grad_find(CairoCtx *c, const char *name) {
    for (int i = 0; i < c->ngrads; i++)
        if (!strcmp(c->grads[i].name, name)) return c->grads[i].pattern;
    return NULL;
}

static void apply_fill(cairo_t *cr, DrawOpts *o, CairoCtx *c) {
    if (o->has_fillname) {
        cairo_pattern_t *p = grad_find(c, o->fillname);
        if (p) { cairo_set_source(cr, p); return; }
    }
    cairo_set_source_rgba(cr, o->fill_r, o->fill_g, o->fill_b,
                          o->fill_a * o->alpha);
}

static void draw_fill_stroke(cairo_t *cr, DrawOpts *o, CairoCtx *c) {
    if (o->has_fill || o->has_fillname) {
        apply_fill(cr, o, c);
        if (o->has_stroke) cairo_fill_preserve(cr);
        else               cairo_fill(cr);
    }
    if (o->has_stroke) {
        apply_stroke_opts(cr, o);
        cairo_set_source_rgba(cr, o->stroke_r, o->stroke_g, o->stroke_b,
                              o->stroke_a * o->alpha);
        cairo_stroke(cr);
    }
    if (!o->has_fill && !o->has_fillname && !o->has_stroke) {
        apply_stroke_opts(cr, o);
        cairo_set_source_rgb(cr, 1, 1, 1);
        cairo_stroke(cr);
    }
}

/* Rounded rectangle */
static void rounded_rect(cairo_t *cr, double x, double y, double w, double h, double r) {
    if (r <= 0) { cairo_rectangle(cr, x, y, w, h); return; }
    if (r > w/2) r = w/2;
    if (r > h/2) r = h/2;
    cairo_move_to(cr, x+r, y);
    cairo_line_to(cr, x+w-r, y);
    cairo_arc(cr, x+w-r, y+r, r, -M_PI/2, 0);
    cairo_line_to(cr, x+w, y+h-r);
    cairo_arc(cr, x+w-r, y+h-r, r, 0, M_PI/2);
    cairo_line_to(cr, x+r, y+h);
    cairo_arc(cr, x+r, y+h-r, r, M_PI/2, M_PI);
    cairo_line_to(cr, x, y+r);
    cairo_arc(cr, x+r, y+r, r, M_PI, 3*M_PI/2);
    cairo_close_path(cr);
}

/* ================================================================== */
/* SVG path parser: M L H V C Q A Z                                  */
/* ================================================================== */

static double parse_num(const char **p) {
    while (**p == ' ' || **p == ',') (*p)++;
    char *end; double v = strtod(*p, &end);
    *p = end; return v;
}

static void apply_svg_path(cairo_t *cr, const char *d) {
    const char *p = d;
    double cx = 0, cy = 0;     /* current point */
    double sx = 0, sy = 0;     /* Start point (for Z) */

    while (*p) {
        while (*p == ' ' || *p == '\n' || *p == '\t') p++;
        if (!*p) break;
        char cmd = *p++;
        int rel = (cmd >= 'a' && cmd <= 'z');
        char ucmd = rel ? (char)(cmd - 32) : cmd;

        do {
            double x, y, x1, y1, x2, y2;
            switch (ucmd) {
            case 'M':
                x = parse_num(&p); y = parse_num(&p);
                if (rel) { x += cx; y += cy; }
                cairo_move_to(cr, x, y);
                cx = sx = x; cy = sy = y;
                ucmd = 'L'; /* weitere Paare = LineTo */
                break;
            case 'L':
                x = parse_num(&p); y = parse_num(&p);
                if (rel) { x += cx; y += cy; }
                cairo_line_to(cr, x, y);
                cx = x; cy = y;
                break;
            case 'H':
                x = parse_num(&p);
                if (rel) x += cx;
                cairo_line_to(cr, x, cy);
                cx = x;
                break;
            case 'V':
                y = parse_num(&p);
                if (rel) y += cy;
                cairo_line_to(cr, cx, y);
                cy = y;
                break;
            case 'C':
                x1=parse_num(&p); y1=parse_num(&p);
                x2=parse_num(&p); y2=parse_num(&p);
                x =parse_num(&p); y =parse_num(&p);
                if (rel) { x1+=cx; y1+=cy; x2+=cx; y2+=cy; x+=cx; y+=cy; }
                cairo_curve_to(cr, x1, y1, x2, y2, x, y);
                cx=x; cy=y;
                break;
            case 'Q': {
                /* Quadratic Bezier -> cubic approximation */
                double qx1=parse_num(&p), qy1=parse_num(&p);
                x=parse_num(&p); y=parse_num(&p);
                if (rel) { qx1+=cx; qy1+=cy; x+=cx; y+=cy; }
                double cx1 = cx + 2.0/3.0*(qx1-cx);
                double cy1 = cy + 2.0/3.0*(qy1-cy);
                double cx2 =  x + 2.0/3.0*(qx1-x);
                double cy2 =  y + 2.0/3.0*(qy1-y);
                cairo_curve_to(cr, cx1, cy1, cx2, cy2, x, y);
                cx=x; cy=y;
                break;
            }
            case 'A': {
                /* Elliptic arc: center parameterization.
                 * xrot is intentionally ignored (no rotation support in v0.1).
                 * For rx==ry this produces a correct circular arc.
                 * General elliptic arcs are approximated. */
                double rx=parse_num(&p), ry=parse_num(&p);
                double xrot=parse_num(&p);
                int large=(int)parse_num(&p), sweep=(int)parse_num(&p);
                x=parse_num(&p); y=parse_num(&p);
                if (rel) { x+=cx; y+=cy; }
                /* Simplified: circular arc when rx==ry and no xrot */
                (void)xrot;
                if (rx <= 0 || ry <= 0) {
                    cairo_line_to(cr, x, y);
                } else {
                    /* Center point parameterization */
                    double dx2=(cx-x)/2.0, dy2=(cy-y)/2.0;
                    double x1p=dx2, y1p=dy2;
                    double sq = ((rx*rx*ry*ry - rx*rx*y1p*y1p - ry*ry*x1p*x1p) /
                                  (rx*rx*y1p*y1p + ry*ry*x1p*x1p));
                    if (sq < 0) sq = 0;
                    double sq2 = sqrt(sq);
                    if (large == sweep) sq2 = -sq2;
                    double cxp =  sq2 * rx*y1p/ry;
                    double cyp = -sq2 * ry*x1p/rx;
                    double mcx = (cx+x)/2.0 + cxp;
                    double mcy = (cy+y)/2.0 + cyp;
                    double ang1 = atan2((y1p-cyp)/ry, (x1p-cxp)/rx);
                    double ang2 = atan2((-y1p-cyp)/ry, (-x1p-cxp)/rx);
                    cairo_save(cr);
                    cairo_translate(cr, mcx, mcy);
                    cairo_scale(cr, rx, ry);
                    if (sweep)
                        cairo_arc(cr, 0, 0, 1, ang1, ang2);
                    else
                        cairo_arc_negative(cr, 0, 0, 1, ang1, ang2);
                    cairo_restore(cr);
                }
                cx=x; cy=y;
                break;
            }
            case 'Z':
            case 'z':
                cairo_close_path(cr);
                cx=sx; cy=sy;
                goto next_cmd;
            default:
                goto next_cmd;
            }
            /* weiteres Koordinatenpaar? */
            while (*p == ' ' || *p == '\t') p++;
        } while (*p && *p != 'M' && *p != 'm' &&
                 *p != 'L' && *p != 'l' &&
                 *p != 'H' && *p != 'h' &&
                 *p != 'V' && *p != 'v' &&
                 *p != 'C' && *p != 'c' &&
                 *p != 'Q' && *p != 'q' &&
                 *p != 'A' && *p != 'a' &&
                 *p != 'Z' && *p != 'z');
        next_cmd:;
    }
}

/* ================================================================== */
/* Tcl commands                                                      */
/* ================================================================== */

/* tkmcairo create width height ?-mode raster|vector? -> id */
static int CairoCreateCmd(ClientData cd, Tcl_Interp *interp,
    int objc, Tcl_Obj *const objv[])
{
    (void)cd;
    if (objc < 4) {
        Tcl_WrongNumArgs(interp, 2, objv, "width height ?-mode raster|vector?");
        return TCL_ERROR;
    }
    int w, h; int vector = 0;
    GET_INT(interp, objv[2], w);
    GET_INT(interp, objv[3], h);
    for (int i = 4; i+1 < objc; i += 2)
        if (!strcmp(Tcl_GetString(objv[i]), "-mode") &&
            !strcmp(Tcl_GetString(objv[i+1]), "vector")) vector = 1;

    CairoCtx *c = (CairoCtx*)calloc(1, sizeof(CairoCtx));
    c->id = g_next_id++; c->width = w; c->height = h; c->vector = vector;
    c->ngrads = 0;

    if (vector) {
        cairo_rectangle_t ext = {0, 0, (double)w, (double)h};
        c->rec     = cairo_recording_surface_create(CAIRO_CONTENT_COLOR_ALPHA, &ext);
        c->surface = c->rec;
        c->cr      = cairo_create(c->rec);
        c->data    = NULL;
    } else {
        c->surface = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, w, h);
        c->cr      = cairo_create(c->surface);
        c->data    = cairo_image_surface_get_data(c->surface);
        c->rec     = NULL;
    }

    if (!ctx_store(c)) {
        cairo_destroy(c->cr); cairo_surface_destroy(c->surface); free(c);
        Tcl_SetResult(interp, "too many contexts", TCL_STATIC);
        return TCL_ERROR;
    }
    Tcl_SetObjResult(interp, Tcl_NewIntObj(c->id));
    return TCL_OK;
}

/* tkmcairo destroy id */
static int CairoDestroyCmd(ClientData cd, Tcl_Interp *interp,
    int objc, Tcl_Obj *const objv[])
{
    (void)cd;
    if (objc < 3) { Tcl_WrongNumArgs(interp,2,objv,"id"); return TCL_ERROR; }
    int id; GET_INT(interp, objv[2], id);
    CairoCtx *c = ctx_find(id);
    if (!c) return TCL_OK;
    /* Release gradients */
    for (int i = 0; i < c->ngrads; i++)
        cairo_pattern_destroy(c->grads[i].pattern);
    cairo_destroy(c->cr);
    if (c->rec && c->rec != c->surface) cairo_surface_destroy(c->rec);
    cairo_surface_destroy(c->surface);
    ctx_remove(id); free(c);
    return TCL_OK;
}

/* tkmcairo clear id r g b ?a? */
static int CairoClearCmd(ClientData cd, Tcl_Interp *interp,
    int objc, Tcl_Obj *const objv[])
{
    (void)cd;
    if (objc < 6) { Tcl_WrongNumArgs(interp,2,objv,"id r g b ?a?"); return TCL_ERROR; }
    int id; GET_INT(interp, objv[2], id);
    CairoCtx *c = ctx_find(id);
    if (!c) { Tcl_SetResult(interp,"invalid id",TCL_STATIC); return TCL_ERROR; }
    double r,g,b,a=1.0;
    GET_DOUBLE(interp,objv[3],r);
    GET_DOUBLE(interp,objv[4],g);
    GET_DOUBLE(interp,objv[5],b);
    if (objc >= 7) GET_DOUBLE(interp,objv[6],a);
    cairo_set_source_rgba(c->cr, r, g, b, a);
    cairo_paint(c->cr);
    return TCL_OK;
}

/* tkmcairo size id -> {w h} */
static int CairoSizeCmd(ClientData cd, Tcl_Interp *interp,
    int objc, Tcl_Obj *const objv[])
{
    (void)cd;
    if (objc < 3) { Tcl_WrongNumArgs(interp,2,objv,"id"); return TCL_ERROR; }
    int id; GET_INT(interp, objv[2], id);
    CairoCtx *c = ctx_find(id);
    if (!c) { Tcl_SetResult(interp,"invalid id",TCL_STATIC); return TCL_ERROR; }
    Tcl_Obj *lst = Tcl_NewListObj(0, NULL);
    Tcl_ListObjAppendElement(interp, lst, Tcl_NewIntObj(c->width));
    Tcl_ListObjAppendElement(interp, lst, Tcl_NewIntObj(c->height));
    Tcl_SetObjResult(interp, lst);
    return TCL_OK;
}

/* tkmcairo todata id -> bytearray ARGB32 */
static int CairoToDataCmd(ClientData cd, Tcl_Interp *interp,
    int objc, Tcl_Obj *const objv[])
{
    (void)cd;
    if (objc < 3) { Tcl_WrongNumArgs(interp,2,objv,"id"); return TCL_ERROR; }
    int id; GET_INT(interp, objv[2], id);
    CairoCtx *c = ctx_find(id);
    if (!c || c->vector) { Tcl_SetResult(interp,"invalid id or vector mode",TCL_STATIC); return TCL_ERROR; }
    cairo_surface_flush(c->surface);
    int stride = cairo_image_surface_get_stride(c->surface);
    Tcl_SetObjResult(interp,
        Tcl_NewByteArrayObj(cairo_image_surface_get_data(c->surface),
                            (Tcl_Size)(stride * c->height)));
    return TCL_OK;
}

/* tkmcairo save id filename */
static int CairoSaveCmd(ClientData cd, Tcl_Interp *interp,
    int objc, Tcl_Obj *const objv[])
{
    (void)cd;
    if (objc < 4) { Tcl_WrongNumArgs(interp,2,objv,"id filename"); return TCL_ERROR; }
    int id; GET_INT(interp, objv[2], id);
    CairoCtx *c = ctx_find(id);
    if (!c) { Tcl_SetResult(interp,"invalid id",TCL_STATIC); return TCL_ERROR; }
    const char *fname = Tcl_GetString(objv[3]);
    const char *dot = strrchr(fname, '.');
    const char *ext = dot ? dot+1 : "";
    int w = c->width, h = c->height;
    cairo_surface_flush(c->surface);

    if (!strcasecmp(ext, "png")) {
        cairo_status_t st;
        if (c->vector) {
            cairo_surface_t *img = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, w, h);
            cairo_t *cr2 = cairo_create(img);
            cairo_set_source_surface(cr2, c->rec, 0, 0); cairo_paint(cr2);
            cairo_destroy(cr2); cairo_surface_flush(img);
            st = cairo_surface_write_to_png(img, fname);
            cairo_surface_destroy(img);
        } else st = cairo_surface_write_to_png(c->surface, fname);
        if (st != CAIRO_STATUS_SUCCESS) {
            Tcl_SetResult(interp,(char*)cairo_status_to_string(st),TCL_VOLATILE);
            return TCL_ERROR;
        }
    } else if (!strcasecmp(ext,"pdf") || !strcasecmp(ext,"svg") ||
               !strcasecmp(ext,"ps")  || !strcasecmp(ext,"eps")) {
        cairo_surface_t *dst;
        if      (!strcasecmp(ext,"pdf")) dst = cairo_pdf_surface_create(fname,(double)w,(double)h);
        else if (!strcasecmp(ext,"svg")) dst = cairo_svg_surface_create(fname,(double)w,(double)h);
        else {
            dst = cairo_ps_surface_create(fname,(double)w,(double)h);
            if (!strcasecmp(ext,"eps")) cairo_ps_surface_set_eps(dst, 1);
        }
        cairo_t *cr2 = cairo_create(dst);
        if (c->vector) {
            cairo_set_source_surface(cr2, c->rec, 0, 0);
        } else {
            unsigned char *data = cairo_image_surface_get_data(c->surface);
            int stride = cairo_image_surface_get_stride(c->surface);
            cairo_surface_t *img = cairo_image_surface_create_for_data(
                data, CAIRO_FORMAT_ARGB32, w, h, stride);
            cairo_set_source_surface(cr2, img, 0, 0);
            cairo_surface_destroy(img);
        }
        cairo_paint(cr2); cairo_show_page(cr2);
        cairo_destroy(cr2); cairo_surface_finish(dst); cairo_surface_destroy(dst);
    } else {
        Tcl_SetResult(interp,"unsupported format: .png .pdf .svg .ps .eps",TCL_STATIC);
        return TCL_ERROR;
    }
    return TCL_OK;
}

/* tkmcairo rect id x y w h ?opts? */
static int CairoRectCmd(ClientData cd, Tcl_Interp *interp,
    int objc, Tcl_Obj *const objv[])
{
    (void)cd;
    if (objc < 7) { Tcl_WrongNumArgs(interp,2,objv,"id x y w h ?opts?"); return TCL_ERROR; }
    int id; GET_INT(interp, objv[2], id);
    CairoCtx *c = ctx_find(id);
    if (!c) { Tcl_SetResult(interp,"invalid id",TCL_STATIC); return TCL_ERROR; }
    double x,y,w,h;
    GET_DOUBLE(interp,objv[3],x); GET_DOUBLE(interp,objv[4],y);
    GET_DOUBLE(interp,objv[5],w); GET_DOUBLE(interp,objv[6],h);
    DrawOpts o; if (!parse_opts(interp,objc,objv,7,&o)) return TCL_ERROR;
    rounded_rect(c->cr, x, y, w, h, o.radius);
    draw_fill_stroke(c->cr, &o, c);
    return TCL_OK;
}

/* tkmcairo line id x1 y1 x2 y2 ?opts? */
static int CairoLineCmd(ClientData cd, Tcl_Interp *interp,
    int objc, Tcl_Obj *const objv[])
{
    (void)cd;
    if (objc < 7) { Tcl_WrongNumArgs(interp,2,objv,"id x1 y1 x2 y2 ?opts?"); return TCL_ERROR; }
    int id; GET_INT(interp, objv[2], id);
    CairoCtx *c = ctx_find(id);
    if (!c) { Tcl_SetResult(interp,"invalid id",TCL_STATIC); return TCL_ERROR; }
    double x1,y1,x2,y2;
    GET_DOUBLE(interp,objv[3],x1); GET_DOUBLE(interp,objv[4],y1);
    GET_DOUBLE(interp,objv[5],x2); GET_DOUBLE(interp,objv[6],y2);
    DrawOpts o; if (!parse_opts(interp,objc,objv,7,&o)) return TCL_ERROR;
    cairo_move_to(c->cr,x1,y1); cairo_line_to(c->cr,x2,y2);
    apply_stroke_opts(c->cr,&o);
    double r = o.has_color?o.color_r:1, g2 = o.has_color?o.color_g:1,
           b = o.has_color?o.color_b:1;
    double ca = o.has_color?o.color_a:1.0;
    cairo_set_source_rgba(c->cr,r,g2,b,ca * o.alpha);
    cairo_stroke(c->cr);
    return TCL_OK;
}

/* tkmcairo circle id cx cy r ?opts? */
static int CairoCircleCmd(ClientData cd, Tcl_Interp *interp,
    int objc, Tcl_Obj *const objv[])
{
    (void)cd;
    if (objc < 6) { Tcl_WrongNumArgs(interp,2,objv,"id cx cy r ?opts?"); return TCL_ERROR; }
    int id; GET_INT(interp, objv[2], id);
    CairoCtx *c = ctx_find(id);
    if (!c) { Tcl_SetResult(interp,"invalid id",TCL_STATIC); return TCL_ERROR; }
    double cx,cy,r;
    GET_DOUBLE(interp,objv[3],cx); GET_DOUBLE(interp,objv[4],cy);
    GET_DOUBLE(interp,objv[5],r);
    DrawOpts o; if (!parse_opts(interp,objc,objv,6,&o)) return TCL_ERROR;
    cairo_arc(c->cr,cx,cy,r,0,2*M_PI);
    draw_fill_stroke(c->cr,&o,c);
    return TCL_OK;
}

/* tkmcairo ellipse id cx cy rx ry ?opts? */
static int CairoEllipseCmd(ClientData cd, Tcl_Interp *interp,
    int objc, Tcl_Obj *const objv[])
{
    (void)cd;
    if (objc < 7) { Tcl_WrongNumArgs(interp,2,objv,"id cx cy rx ry ?opts?"); return TCL_ERROR; }
    int id; GET_INT(interp, objv[2], id);
    CairoCtx *c = ctx_find(id);
    if (!c) { Tcl_SetResult(interp,"invalid id",TCL_STATIC); return TCL_ERROR; }
    double cx,cy,rx,ry;
    GET_DOUBLE(interp,objv[3],cx); GET_DOUBLE(interp,objv[4],cy);
    GET_DOUBLE(interp,objv[5],rx); GET_DOUBLE(interp,objv[6],ry);
    DrawOpts o; if (!parse_opts(interp,objc,objv,7,&o)) return TCL_ERROR;
    cairo_save(c->cr);
    cairo_translate(c->cr,cx,cy); cairo_scale(c->cr,rx,ry);
    cairo_arc(c->cr,0,0,1,0,2*M_PI);
    cairo_restore(c->cr);
    draw_fill_stroke(c->cr,&o,c);
    return TCL_OK;
}

/* tkmcairo arc id cx cy r start_deg end_deg ?opts? */
static int CairoArcCmd(ClientData cd, Tcl_Interp *interp,
    int objc, Tcl_Obj *const objv[])
{
    (void)cd;
    if (objc < 8) { Tcl_WrongNumArgs(interp,2,objv,"id cx cy r start end ?opts?"); return TCL_ERROR; }
    int id; GET_INT(interp, objv[2], id);
    CairoCtx *c = ctx_find(id);
    if (!c) { Tcl_SetResult(interp,"invalid id",TCL_STATIC); return TCL_ERROR; }
    double cx,cy,r,s,e;
    GET_DOUBLE(interp,objv[3],cx); GET_DOUBLE(interp,objv[4],cy);
    GET_DOUBLE(interp,objv[5],r);
    GET_DOUBLE(interp,objv[6],s); GET_DOUBLE(interp,objv[7],e);
    DrawOpts o; if (!parse_opts(interp,objc,objv,8,&o)) return TCL_ERROR;
    cairo_arc(c->cr, cx, cy, r, s*M_PI/180.0, e*M_PI/180.0);
    draw_fill_stroke(c->cr,&o,c);
    return TCL_OK;
}

/* tkmcairo poly id x1 y1 x2 y2 ... ?opts? */
static int CairoPolyCmd(ClientData cd, Tcl_Interp *interp,
    int objc, Tcl_Obj *const objv[])
{
    (void)cd;
    if (objc < 6) { Tcl_WrongNumArgs(interp,2,objv,"id x1 y1 ... ?opts?"); return TCL_ERROR; }
    int id; GET_INT(interp, objv[2], id);
    CairoCtx *c = ctx_find(id);
    if (!c) { Tcl_SetResult(interp,"invalid id",TCL_STATIC); return TCL_ERROR; }

    /* Find coordinate pairs: until first -opt */
    int coord_end = 3;
    while (coord_end+1 < objc) {
        const char *s = Tcl_GetString(objv[coord_end]);
        if (s[0] == '-' && !isdigit((unsigned char)s[1])) break;
        coord_end++;
    }
    int ncoords = coord_end - 3;
    if (ncoords < 6 || ncoords % 2 != 0) {
        Tcl_SetResult(interp,"poly: need at least 3 coordinate pairs (6 values)",TCL_STATIC);
        return TCL_ERROR;
    }
    DrawOpts o; if (!parse_opts(interp,objc,objv,coord_end,&o)) return TCL_ERROR;
    double x,y;
    GET_DOUBLE(interp,objv[3],x); GET_DOUBLE(interp,objv[4],y);
    cairo_move_to(c->cr,x,y);
    for (int i=5; i+1 < coord_end; i+=2) {
        GET_DOUBLE(interp,objv[i],x);
        GET_DOUBLE(interp,objv[i+1],y);
        cairo_line_to(c->cr,x,y);
    }
    cairo_close_path(c->cr);
    draw_fill_stroke(c->cr,&o,c);
    return TCL_OK;
}

/* tkmcairo path id svgdata ?opts? */
static int CairoPathCmd(ClientData cd, Tcl_Interp *interp,
    int objc, Tcl_Obj *const objv[])
{
    (void)cd;
    if (objc < 4) { Tcl_WrongNumArgs(interp,2,objv,"id svgdata ?opts?"); return TCL_ERROR; }
    int id; GET_INT(interp, objv[2], id);
    CairoCtx *c = ctx_find(id);
    if (!c) { Tcl_SetResult(interp,"invalid id",TCL_STATIC); return TCL_ERROR; }
    const char *d = Tcl_GetString(objv[3]);
    DrawOpts o; if (!parse_opts(interp,objc,objv,4,&o)) return TCL_ERROR;
    apply_svg_path(c->cr, d);
    draw_fill_stroke(c->cr,&o,c);
    return TCL_OK;
}

/* tkmcairo text id x y string ?opts? */
static int CairoTextCmd(ClientData cd, Tcl_Interp *interp,
    int objc, Tcl_Obj *const objv[])
{
    (void)cd;
    if (objc < 6) { Tcl_WrongNumArgs(interp,2,objv,"id x y string ?opts?"); return TCL_ERROR; }
    int id; GET_INT(interp, objv[2], id);
    CairoCtx *c = ctx_find(id);
    if (!c) { Tcl_SetResult(interp,"invalid id",TCL_STATIC); return TCL_ERROR; }
    double x,y;
    GET_DOUBLE(interp,objv[3],x); GET_DOUBLE(interp,objv[4],y);
    const char *text = Tcl_GetString(objv[5]);
    DrawOpts o; if (!parse_opts(interp,objc,objv,6,&o)) return TCL_ERROR;

    char family[64]="Sans"; double sz; cairo_font_weight_t wt; cairo_font_slant_t sl;
    parse_font(o.font, family, sizeof(family), &wt, &sl, &sz);

    cairo_select_font_face(c->cr, family, sl, wt);
    cairo_set_font_size(c->cr, sz);

    cairo_text_extents_t ext; cairo_font_extents_t fext;
    cairo_text_extents(c->cr, text, &ext);
    cairo_font_extents(c->cr, &fext);

    double tx=x, ty=y;
    const char *a = o.anchor;
    if (!strcmp(a,"center")||!strcmp(a,"n")||!strcmp(a,"s"))
        tx = x - ext.width/2.0 - ext.x_bearing;
    else if (!strcmp(a,"e")||!strcmp(a,"ne")||!strcmp(a,"se"))
        tx = x - ext.width - ext.x_bearing;
    if (!strcmp(a,"nw")||!strcmp(a,"n")||!strcmp(a,"ne"))
        ty = y + fext.ascent;
    else if (!strcmp(a,"center")||!strcmp(a,"w")||!strcmp(a,"e"))
        ty = y + fext.ascent/2.0;
    else if (!strcmp(a,"sw")||!strcmp(a,"s")||!strcmp(a,"se"))
        ty = y;  /* Baseline = sw Standard */

    double r = o.has_color?o.color_r:1, g2=o.has_color?o.color_g:1,
           b  = o.has_color?o.color_b:1;
    /* Fix: color_a aus -color verwenden (nicht global alpha) */
    double ca = o.has_color?o.color_a:1.0;
    cairo_set_source_rgba(c->cr, r, g2, b, ca * o.alpha);
    cairo_move_to(c->cr, tx, ty);
    cairo_show_text(c->cr, text);
    return TCL_OK;
}

/* tkmcairo font_measure id string font -> {width height ascent descent} */
static int CairoFontMeasureCmd(ClientData cd, Tcl_Interp *interp,
    int objc, Tcl_Obj *const objv[])
{
    (void)cd;
    if (objc < 5) { Tcl_WrongNumArgs(interp,2,objv,"id string font"); return TCL_ERROR; }
    int id; GET_INT(interp, objv[2], id);
    CairoCtx *c = ctx_find(id);
    if (!c) { Tcl_SetResult(interp,"invalid id",TCL_STATIC); return TCL_ERROR; }
    const char *text=Tcl_GetString(objv[3]), *fontspec=Tcl_GetString(objv[4]);
    char family[64]="Sans"; double sz; cairo_font_weight_t wt; cairo_font_slant_t sl;
    parse_font(fontspec, family, sizeof(family), &wt, &sl, &sz);
    cairo_save(c->cr);
    cairo_select_font_face(c->cr,family,sl,wt); cairo_set_font_size(c->cr,sz);
    cairo_text_extents_t ext; cairo_font_extents_t fext;
    cairo_text_extents(c->cr,text,&ext); cairo_font_extents(c->cr,&fext);
    cairo_restore(c->cr);
    Tcl_Obj *res = Tcl_NewListObj(0,NULL);
    Tcl_ListObjAppendElement(interp,res,Tcl_NewDoubleObj(ext.width));
    Tcl_ListObjAppendElement(interp,res,Tcl_NewDoubleObj(fext.height));
    Tcl_ListObjAppendElement(interp,res,Tcl_NewDoubleObj(fext.ascent));
    Tcl_ListObjAppendElement(interp,res,Tcl_NewDoubleObj(fext.descent));
    Tcl_SetObjResult(interp,res);
    return TCL_OK;
}

/* tkmcairo transform id -translate x y | -scale sx sy | -rotate deg | -reset */
static int CairoTransformCmd(ClientData cd, Tcl_Interp *interp,
    int objc, Tcl_Obj *const objv[])
{
    (void)cd;
    if (objc < 4) { Tcl_WrongNumArgs(interp,2,objv,"id op ?args?"); return TCL_ERROR; }
    int id; GET_INT(interp, objv[2], id);
    CairoCtx *c = ctx_find(id);
    if (!c) { Tcl_SetResult(interp,"invalid id",TCL_STATIC); return TCL_ERROR; }
    const char *op = Tcl_GetString(objv[3]);
    if (!strcmp(op,"-translate") && objc >= 6) {
        double x,y; GET_DOUBLE(interp,objv[4],x); GET_DOUBLE(interp,objv[5],y);
        cairo_translate(c->cr,x,y);
    } else if (!strcmp(op,"-scale") && objc >= 6) {
        double sx,sy; GET_DOUBLE(interp,objv[4],sx); GET_DOUBLE(interp,objv[5],sy);
        cairo_scale(c->cr,sx,sy);
    } else if (!strcmp(op,"-rotate") && objc >= 5) {
        double deg; GET_DOUBLE(interp,objv[4],deg);
        cairo_rotate(c->cr, deg*M_PI/180.0);
    } else if (!strcmp(op,"-reset")) {
        cairo_identity_matrix(c->cr);
    } else {
        Tcl_SetResult(interp,"transform: -translate x y | -scale sx sy | -rotate deg | -reset",TCL_STATIC);
        return TCL_ERROR;
    }
    return TCL_OK;
}

/* tkmcairo gradient_linear id name x1 y1 x2 y2 stops
 * tkmcairo gradient_radial  id name cx cy r stops
 * stops: {{offset r g b a} ...} */
static int CairoGradientCmd(ClientData cd, Tcl_Interp *interp,
    int objc, Tcl_Obj *const objv[], int radial)
{
    (void)cd;
    int minargs = radial ? 8 : 9;
    if (objc < minargs) {
        if (radial) Tcl_WrongNumArgs(interp,2,objv,"id name cx cy r stops");
        else        Tcl_WrongNumArgs(interp,2,objv,"id name x1 y1 x2 y2 stops");
        return TCL_ERROR;
    }
    int id; GET_INT(interp, objv[2], id);
    CairoCtx *c = ctx_find(id);
    if (!c) { Tcl_SetResult(interp,"invalid id",TCL_STATIC); return TCL_ERROR; }
    const char *name = Tcl_GetString(objv[3]);
    /* First check if name already exists — replace is always allowed */
    for (int _i=0; _i<c->ngrads; _i++) {
        if (!strcmp(c->grads[_i].name, name)) goto _grad_build;
    }
    /* New name — check capacity */
    if (c->ngrads >= MAX_GRAD) {
        Tcl_SetResult(interp,"too many gradients",TCL_STATIC);
        return TCL_ERROR;
    }
    _grad_build:;
    cairo_pattern_t *pat;

    if (radial) {
        double cx,cy,r;
        GET_DOUBLE(interp,objv[4],cx); GET_DOUBLE(interp,objv[5],cy);
        GET_DOUBLE(interp,objv[6],r);
        pat = cairo_pattern_create_radial(cx,cy,0, cx,cy,r);
        /* stops in objv[7] */
        Tcl_Size n; Tcl_Obj **stops;
        Tcl_ListObjGetElements(interp,objv[7],&n,&stops);
        for (Tcl_Size i=0; i<n; i++) {
            Tcl_Size m; Tcl_Obj **s;
            if (Tcl_ListObjGetElements(interp,stops[i],&m,&s)==TCL_OK && m>=4) {
                double off,r2,g2,b2,a2=1.0;
                if (Tcl_GetDoubleFromObj(interp,s[0],&off) != TCL_OK) continue;
                if (Tcl_GetDoubleFromObj(interp,s[1],&r2)  != TCL_OK) continue;
                if (Tcl_GetDoubleFromObj(interp,s[2],&g2)  != TCL_OK) continue;
                if (Tcl_GetDoubleFromObj(interp,s[3],&b2)  != TCL_OK) continue;
                if (m>=5 && Tcl_GetDoubleFromObj(interp,s[4],&a2) != TCL_OK) a2=1.0;
                cairo_pattern_add_color_stop_rgba(pat,off,r2,g2,b2,a2);
            }
        }
    } else {
        double x1,y1,x2,y2;
        GET_DOUBLE(interp,objv[4],x1); GET_DOUBLE(interp,objv[5],y1);
        GET_DOUBLE(interp,objv[6],x2); GET_DOUBLE(interp,objv[7],y2);
        pat = cairo_pattern_create_linear(x1,y1,x2,y2);
        Tcl_Size n; Tcl_Obj **stops;
        Tcl_ListObjGetElements(interp,objv[8],&n,&stops);
        for (Tcl_Size i=0; i<n; i++) {
            Tcl_Size m; Tcl_Obj **s;
            if (Tcl_ListObjGetElements(interp,stops[i],&m,&s)==TCL_OK && m>=4) {
                double off,r2,g2,b2,a2=1.0;
                if (Tcl_GetDoubleFromObj(interp,s[0],&off) != TCL_OK) continue;
                if (Tcl_GetDoubleFromObj(interp,s[1],&r2)  != TCL_OK) continue;
                if (Tcl_GetDoubleFromObj(interp,s[2],&g2)  != TCL_OK) continue;
                if (Tcl_GetDoubleFromObj(interp,s[3],&b2)  != TCL_OK) continue;
                if (m>=5 && Tcl_GetDoubleFromObj(interp,s[4],&a2) != TCL_OK) a2=1.0;
                cairo_pattern_add_color_stop_rgba(pat,off,r2,g2,b2,a2);
            }
        }
    }

    /* Replace existing gradient with same name */
    for (int i=0; i<c->ngrads; i++) {
        if (!strcmp(c->grads[i].name, name)) {
            cairo_pattern_destroy(c->grads[i].pattern);
            c->grads[i].pattern = pat;
            return TCL_OK;
        }
    }
    strncpy(c->grads[c->ngrads].name, name, 63);
    c->grads[c->ngrads].name[63] = '\0';
    c->grads[c->ngrads].pattern = pat;
    c->ngrads++;
    return TCL_OK;
}

/* ================================================================== */
/* Ensemble dispatcher                                                */
/* ================================================================== */

static int TkmCairoCmd(ClientData cd, Tcl_Interp *interp,
    int objc, Tcl_Obj *const objv[])
{
    if (objc < 2) {
        Tcl_WrongNumArgs(interp, 1, objv,
            "create|destroy|clear|save|size|todata|"
            "rect|line|circle|ellipse|arc|poly|path|text|"
            "font_measure|transform|gradient_linear|gradient_radial ...");
        return TCL_ERROR;
    }
    const char *sub = Tcl_GetString(objv[1]);

    if      (!strcmp(sub,"create"))           return CairoCreateCmd(cd,interp,objc,objv);
    else if (!strcmp(sub,"destroy"))          return CairoDestroyCmd(cd,interp,objc,objv);
    else if (!strcmp(sub,"clear"))            return CairoClearCmd(cd,interp,objc,objv);
    else if (!strcmp(sub,"size"))             return CairoSizeCmd(cd,interp,objc,objv);
    else if (!strcmp(sub,"todata"))           return CairoToDataCmd(cd,interp,objc,objv);
    else if (!strcmp(sub,"save"))             return CairoSaveCmd(cd,interp,objc,objv);
    else if (!strcmp(sub,"rect"))             return CairoRectCmd(cd,interp,objc,objv);
    else if (!strcmp(sub,"line"))             return CairoLineCmd(cd,interp,objc,objv);
    else if (!strcmp(sub,"circle"))           return CairoCircleCmd(cd,interp,objc,objv);
    else if (!strcmp(sub,"ellipse"))          return CairoEllipseCmd(cd,interp,objc,objv);
    else if (!strcmp(sub,"arc"))              return CairoArcCmd(cd,interp,objc,objv);
    else if (!strcmp(sub,"poly"))             return CairoPolyCmd(cd,interp,objc,objv);
    else if (!strcmp(sub,"path"))             return CairoPathCmd(cd,interp,objc,objv);
    else if (!strcmp(sub,"text"))             return CairoTextCmd(cd,interp,objc,objv);
    else if (!strcmp(sub,"font_measure"))     return CairoFontMeasureCmd(cd,interp,objc,objv);
    else if (!strcmp(sub,"transform"))        return CairoTransformCmd(cd,interp,objc,objv);
    else if (!strcmp(sub,"gradient_linear"))  return CairoGradientCmd(cd,interp,objc,objv,0);
    else if (!strcmp(sub,"gradient_radial"))  return CairoGradientCmd(cd,interp,objc,objv,1);
    else {
        Tcl_SetObjResult(interp,
            Tcl_ObjPrintf("unknown subcommand \"%s\"", sub));
        return TCL_ERROR;
    }
}

/* ================================================================== */
/* Package init                                                        */
/* ================================================================== */

int Tkmcairo_Init(Tcl_Interp *interp)
{
#ifdef USE_TCL_STUBS
    /* Tcl 9.x changed major version — "8.6" does not satisfy "9.0"
     * Solution: try 9.0 first, fall back to 8.6 */
#if TCL_MAJOR_VERSION >= 9
    if (Tcl_InitStubs(interp, "9.0", 0) == NULL) return TCL_ERROR;
#else
    if (Tcl_InitStubs(interp, "8.6", 0) == NULL) return TCL_ERROR;
#endif
#endif
    Tcl_CreateObjCommand(interp, "tkmcairo", TkmCairoCmd, NULL, NULL);
    Tcl_PkgProvide(interp, "tkmcairo", "0.1");
    return TCL_OK;
}