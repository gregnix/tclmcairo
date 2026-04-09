/*
 * libtclmcairo.c
 * tclmcairo -- Cairo 2D graphics library for Tcl
 *
 * Version: 0.3
 * Lizenz:  BSD
 *
 * No dependency on Tk, X11, or Wayland.
 * Runs in tclsh. Output: PNG, PDF, SVG, PS/EPS.
 *
 * Thread safety: NOT thread-safe.
 * All contexts (g_ctx[]) are global state shared across the interpreter.
 * Use one tclmcairo interpreter per thread, or add external locking.
 * This matches Tk's threading model — safe for single-threaded Tcl use.
 *
 * Tcl API:
 *   tclmcairo create width height ?-mode raster|vector|pdf|svg|ps|eps? ?-file f?
 *   tclmcairo destroy handle
 *   tclmcairo clear  handle r g b ?a?
 *   tclmcairo save   handle filename          (.png .pdf .svg .ps .eps)
 *   tclmcairo size   handle                   -> {w h}
 *   tclmcairo todata handle                   -> bytearray ARGB32
 *   tclmcairo newpage handle                  (multi-page PDF/PS/SVG)
 *   tclmcairo finish  handle                  (flush + close file-mode)
 *
 *   tclmcairo rect   handle x y w h opts
 *   tclmcairo line   handle x1 y1 x2 y2 opts
 *   tclmcairo circle handle cx cy r opts
 *   tclmcairo ellipse handle cx cy rx ry opts
 *   tclmcairo arc    handle cx cy r start end opts
 *   tclmcairo poly   handle x1 y1 x2 y2 ... opts
 *   tclmcairo path   handle svgdata opts      (M L C Q A Z)
 *   tclmcairo text   handle x y string opts
 *   tclmcairo text_path handle x y string opts  (text as path -> fill/stroke)
 *
 *   tclmcairo image  handle filename x y ?-width w? ?-height h? ?-alpha a?
 *
 *   tclmcairo clip_rect  handle x y w h
 *   tclmcairo clip_path  handle svgdata
 *   tclmcairo clip_reset handle
 *   tclmcairo push       handle              (cairo_save)
 *   tclmcairo pop        handle              (cairo_restore)
 *
 *   tclmcairo font_measure handle string font -> {width height ascent descent}
 *   tclmcairo transform handle -translate x y | -scale sx sy | -rotate deg | -reset
 *
 *   tclmcairo gradient_linear handle name x1 y1 x2 y2 stops
 *   tclmcairo gradient_radial handle name cx cy r stops
 *   (stops: {{offset r g b a} ...})
 *
 * Options (as key/value pairs after coordinates):
 *   -fill      {r g b ?a?}     Fill color
 *   -stroke    {r g b ?a?}     Stroke color
 *   -color     {r g b ?a?}     Text color
 *   -width     n               Line width
 *   -dash      {on off ...}    Dash pattern
 *   -font      "Family Bold Italic Size"
 *   -alpha     0.0..1.0        Global alpha
 *   -anchor    nw|n|ne|w|center|e|sw|s|se
 *   -radius    r               Corner radius for rect
 *   -fillname  gradname        Gradient as fill
 *   -linecap   butt|round|square
 *   -linejoin  miter|round|bevel
 *   -fillrule  winding|evenodd (for path/poly)
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

/* Optional JPEG support via libjpeg */
#ifdef HAVE_LIBJPEG
#  include <jpeglib.h>
#  include <setjmp.h>
#endif

/* File-mode constants */
#define MODE_RASTER   0
#define MODE_VECTOR   1   /* recording surface */
#define MODE_PDF      2
#define MODE_SVG      3
#define MODE_PS       4
#define MODE_EPS      5

/* Tcl_Size Kompatibilitaet: Tcl 8.6 hat kein Tcl_Size (erst ab 8.7/9.0)
 * In Tcl 9.0 ist Tcl_Size = ptrdiff_t (64-bit sauber).
 * Der Shim macht libtclmcairo.c auf 8.6 und 9.0 kompilierbar. */
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
    int              mode;          /* MODE_* constant */
    int              vector;        /* 0=raster 1=recording/file */
    cairo_format_t   fmt;           /* CAIRO_FORMAT_ARGB32|RGB24|A8 */
    cairo_surface_t *surface;
    cairo_surface_t *rec;           /* recording surface (vector) */
    cairo_t         *cr;
    unsigned char   *data;          /* raster pixel data */
    Gradient         grads[MAX_GRAD];
    int              ngrads;
    int              finished;      /* file-mode: already finished */
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
    double  dash_offset;     /* starting offset into dash pattern */
    int     linecap;   /* 0=butt 1=round 2=square */
    int     linejoin;  /* 0=miter 1=round 2=bevel */
    int     fillrule;  /* 0=winding 1=evenodd */
    int     outline;   /* 0=show_text 1=text_path (font-independent SVG) */
} DrawOpts;

static void opts_defaults(DrawOpts *o) {
    o->fill_r=1; o->fill_g=1; o->fill_b=1; o->fill_a=1; o->has_fill=0;
    o->stroke_r=0; o->stroke_g=0; o->stroke_b=0; o->stroke_a=1; o->has_stroke=0;
    o->color_r=1; o->color_g=1; o->color_b=1; o->color_a=1; o->has_color=0;
    o->line_width=1.5; o->alpha=1.0; o->radius=0.0;
    strncpy(o->font, "Sans 14", sizeof(o->font)-1);
    strncpy(o->anchor, "sw", sizeof(o->anchor)-1);
    o->has_fillname=0; o->fillname[0]='\0';
    o->ndash=0; o->dash_offset=0.0; o->linecap=0; o->linejoin=0; o->fillrule=0; o->outline=0;
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
                Tcl_SetObjResult(interp, Tcl_ObjPrintf("invalid -linecap: %s (butt|round|square)", s));
                return 0;
            }
        }
        else if (!strcmp(k,"-linejoin")) {
            const char *s=Tcl_GetString(v);
            if     (!strcmp(s,"miter")) o->linejoin=0;
            else if(!strcmp(s,"round")) o->linejoin=1;
            else if(!strcmp(s,"bevel")) o->linejoin=2;
            else {
                Tcl_SetObjResult(interp, Tcl_ObjPrintf("invalid -linejoin: %s (miter|round|bevel)", s));
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
        else if (!strcmp(k,"-dash_offset")) {
            if (Tcl_GetDoubleFromObj(interp,v,&o->dash_offset) != TCL_OK) return 0;
        }
        else if (!strcmp(k,"-fillrule")) {
            const char *s=Tcl_GetString(v);
            if     (!strcmp(s,"winding")) o->fillrule=0;
            else if(!strcmp(s,"evenodd")) o->fillrule=1;
            else {
                Tcl_SetObjResult(interp, Tcl_ObjPrintf("invalid -fillrule: %s (winding|evenodd)", s));
                return 0;
            }
        }
        else if (!strcmp(k,"-outline")) {
            int b; if (Tcl_GetBooleanFromObj(interp,v,&b) != TCL_OK) return 0;
            o->outline = b;
        }
        /* Fix: unbekannte Option -> TCL_ERROR */
        else {
            Tcl_SetObjResult(interp, Tcl_ObjPrintf("%s\"", k));
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
        cairo_set_dash(cr, o->dash, o->ndash, o->dash_offset);
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
    cairo_set_fill_rule(cr, o->fillrule ? CAIRO_FILL_RULE_EVEN_ODD
                                        : CAIRO_FILL_RULE_WINDING);
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

/* ================================================================== */
/* Cairo status check helper — call after drawing operations          */
/* Returns TCL_OK or TCL_ERROR with cairo error message.              */
/* ================================================================== */
static int check_cairo(Tcl_Interp *interp, cairo_t *cr, const char *where __attribute__((unused)))
{
    cairo_status_t st = cairo_status(cr);
    if (st == CAIRO_STATUS_SUCCESS) return TCL_OK;
    Tcl_SetObjResult(interp, Tcl_ObjPrintf(": %s", cairo_status_to_string(st)));
    return TCL_ERROR;
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

static int parse_num(const char **p, double *out) {
    while (**p == ' ' || **p == ',' || **p == '\n' || **p == '\t') (*p)++;
    if (!**p) return 0;
    char *end;
    double v = strtod(*p, &end);
    if (end == *p) return 0;   /* no number parsed — stop, avoid infinite loop */
    *p = end;
    *out = v;
    return 1;
}

#define PARSE_NUM(pp, var) do { if (!parse_num((pp), &(var))) goto path_parse_error; } while(0)

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
                PARSE_NUM(&p, x); PARSE_NUM(&p, y);
                if (rel) { x += cx; y += cy; }
                cairo_move_to(cr, x, y);
                cx = sx = x; cy = sy = y;
                ucmd = 'L'; /* weitere Paare = LineTo */
                break;
            case 'L':
                PARSE_NUM(&p, x); PARSE_NUM(&p, y);
                if (rel) { x += cx; y += cy; }
                cairo_line_to(cr, x, y);
                cx = x; cy = y;
                break;
            case 'H':
                PARSE_NUM(&p, x);
                if (rel) x += cx;
                cairo_line_to(cr, x, cy);
                cx = x;
                break;
            case 'V':
                PARSE_NUM(&p, y);
                if (rel) y += cy;
                cairo_line_to(cr, cx, y);
                cy = y;
                break;
            case 'C':
                PARSE_NUM(&p, x1); PARSE_NUM(&p, y1);
                PARSE_NUM(&p, x2); PARSE_NUM(&p, y2);
                PARSE_NUM(&p, x); PARSE_NUM(&p, y);
                if (rel) { x1+=cx; y1+=cy; x2+=cx; y2+=cy; x+=cx; y+=cy; }
                cairo_curve_to(cr, x1, y1, x2, y2, x, y);
                cx=x; cy=y;
                break;
            case 'Q': {
                /* Quadratic Bezier -> cubic approximation */
                double qx1, qy1;
                PARSE_NUM(&p, qx1); PARSE_NUM(&p, qy1);
                PARSE_NUM(&p, x);   PARSE_NUM(&p, y);
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
                double rx, ry, xrot;
                PARSE_NUM(&p, rx); PARSE_NUM(&p, ry); PARSE_NUM(&p, xrot);
                double large_d, sweep_d;
                PARSE_NUM(&p, large_d); PARSE_NUM(&p, sweep_d);
                int large = (int)large_d, sweep = (int)sweep_d;
                PARSE_NUM(&p, x); PARSE_NUM(&p, y);
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
    return;
path_parse_error:
    /* Bad number in SVG path data — stop parsing, keep what was drawn so far */
    return;
}

/* ================================================================== */
/* Tcl commands                                                      */
/* ================================================================== */

/* tclmcairo create width height ?-mode raster|vector? -> id */
static int CairoCreateCmd(ClientData cd, Tcl_Interp *interp,
    int objc, Tcl_Obj *const objv[])
{
    (void)cd;
    if (objc < 4) {
        Tcl_WrongNumArgs(interp, 2, objv,
            "width height ?-mode raster|vector|pdf|svg|ps|eps?"
            " ?-file filename? ?-format argb32|rgb24|a8?"
            " ?-svg_version 1.1|1.2? ?-svg_unit pt|px|mm|cm|in?");
        return TCL_ERROR;
    }
    int w, h;
    GET_INT(interp, objv[2], w);
    GET_INT(interp, objv[3], h);

    int mode = MODE_RASTER;
    const char *filename = NULL;
    cairo_format_t fmt = CAIRO_FORMAT_ARGB32;
    int svg_version = -1;   /* -1 = default (SVG 1.2) */
    int svg_unit   = -1;    /* -1 = default (pt) */

    for (int i = 4; i+1 < objc; i += 2) {
        const char *k = Tcl_GetString(objv[i]);
        const char *v = Tcl_GetString(objv[i+1]);
        if (!strcmp(k, "-mode")) {
            if      (!strcmp(v,"raster")) mode = MODE_RASTER;
            else if (!strcmp(v,"vector")) mode = MODE_VECTOR;
            else if (!strcmp(v,"pdf"))    mode = MODE_PDF;
            else if (!strcmp(v,"svg"))    mode = MODE_SVG;
            else if (!strcmp(v,"ps"))     mode = MODE_PS;
            else if (!strcmp(v,"eps"))    mode = MODE_EPS;
            else {
                Tcl_SetObjResult(interp, Tcl_ObjPrintf("invalid -mode: %s (raster|vector|pdf|svg|ps|eps)", v));
                return TCL_ERROR;
            }
        } else if (!strcmp(k, "-file")) {
            filename = v;
        } else if (!strcmp(k, "-format")) {
            if      (!strcmp(v,"argb32")) fmt = CAIRO_FORMAT_ARGB32;
            else if (!strcmp(v,"rgb24"))  fmt = CAIRO_FORMAT_RGB24;
            else if (!strcmp(v,"a8"))     fmt = CAIRO_FORMAT_A8;
            else {
                Tcl_SetObjResult(interp, Tcl_ObjPrintf("invalid -format: %s (argb32|rgb24|a8)", v));
                return TCL_ERROR;
            }
        } else if (!strcmp(k, "-svg_version")) {
            if      (!strcmp(v,"1.1")) svg_version = CAIRO_SVG_VERSION_1_1;
            else if (!strcmp(v,"1.2")) svg_version = CAIRO_SVG_VERSION_1_2;
            else {
                Tcl_SetObjResult(interp, Tcl_ObjPrintf("invalid -svg_version: %s (1.1|1.2)", v));
                return TCL_ERROR;
            }
        } else if (!strcmp(k, "-svg_unit")) {
            if      (!strcmp(v,"pt"))  svg_unit = CAIRO_SVG_UNIT_PT;
            else if (!strcmp(v,"px"))  svg_unit = CAIRO_SVG_UNIT_PX;
            else if (!strcmp(v,"mm"))  svg_unit = CAIRO_SVG_UNIT_MM;
            else if (!strcmp(v,"cm"))  svg_unit = CAIRO_SVG_UNIT_CM;
            else if (!strcmp(v,"in"))  svg_unit = CAIRO_SVG_UNIT_IN;
            else if (!strcmp(v,"em"))  svg_unit = CAIRO_SVG_UNIT_EM;
            else if (!strcmp(v,"ex"))  svg_unit = CAIRO_SVG_UNIT_EX;
            else if (!strcmp(v,"pc"))  svg_unit = CAIRO_SVG_UNIT_PC;
            else {
                Tcl_SetObjResult(interp, Tcl_ObjPrintf("invalid -svg_unit: %s (pt|px|mm|cm|in|em|ex|pc)", v));
                return TCL_ERROR;
            }
        } else {
            Tcl_SetObjResult(interp, Tcl_ObjPrintf("%s\" — use -mode -file -format -svg_version -svg_unit", k));
            return TCL_ERROR;
        }
    }
    /* odd number of option args */
    if ((objc - 4) % 2 != 0) {
        Tcl_SetObjResult(interp, Tcl_ObjPrintf("option \"%s\" has no value", Tcl_GetString(objv[objc-1])));
        return TCL_ERROR;
    }

    /* file modes require -file */
    if ((mode == MODE_PDF || mode == MODE_SVG ||
         mode == MODE_PS  || mode == MODE_EPS) && !filename) {
        Tcl_SetResult(interp, "-mode pdf|svg|ps|eps requires -file filename",
                      TCL_STATIC);
        return TCL_ERROR;
    }

    CairoCtx *c = (CairoCtx*)calloc(1, sizeof(CairoCtx));
    c->id = g_next_id++; c->width = w; c->height = h;
    c->mode = mode; c->ngrads = 0; c->finished = 0;
    c->fmt  = fmt;
    c->vector = (mode != MODE_RASTER);

    switch (mode) {
    case MODE_RASTER:
        c->surface = cairo_image_surface_create(fmt, w, h);
        if (cairo_surface_status(c->surface) != CAIRO_STATUS_SUCCESS) {
            Tcl_SetObjResult(interp, Tcl_ObjPrintf("%s", cairo_status_to_string(cairo_surface_status(c->surface))));
            free(c); return TCL_ERROR;
        }
        c->cr   = cairo_create(c->surface);
        c->data = cairo_image_surface_get_data(c->surface);
        c->rec  = NULL;
        break;
    case MODE_VECTOR: {
        cairo_rectangle_t ext = {0, 0, (double)w, (double)h};
        c->rec     = cairo_recording_surface_create(CAIRO_CONTENT_COLOR_ALPHA, &ext);
        c->surface = c->rec;
        c->cr      = cairo_create(c->rec);
        c->data    = NULL;
        break;
    }
    case MODE_PDF:
        c->surface = cairo_pdf_surface_create(filename, (double)w, (double)h);
        c->cr      = cairo_create(c->surface);
        c->rec     = NULL; c->data = NULL;
        break;
    case MODE_SVG:
        c->surface = cairo_svg_surface_create(filename, (double)w, (double)h);
        if (svg_version >= 0)
            cairo_svg_surface_restrict_to_version(c->surface,
                (cairo_svg_version_t)svg_version);
        if (svg_unit >= 0)
            cairo_svg_surface_set_document_unit(c->surface,
                (cairo_svg_unit_t)svg_unit);
        c->cr  = cairo_create(c->surface);
        c->rec = NULL; c->data = NULL;
        break;
    case MODE_PS:
    case MODE_EPS:
        c->surface = cairo_ps_surface_create(filename, (double)w, (double)h);
        if (mode == MODE_EPS) cairo_ps_surface_set_eps(c->surface, 1);
        c->cr      = cairo_create(c->surface);
        c->rec     = NULL; c->data = NULL;
        break;
    }

    /* Check cairo_t status after create */
    if (cairo_status(c->cr) != CAIRO_STATUS_SUCCESS) {
        Tcl_SetObjResult(interp, Tcl_ObjPrintf("%s", cairo_status_to_string(cairo_status(c->cr))));
        cairo_destroy(c->cr);
        if (c->rec && c->rec != c->surface) cairo_surface_destroy(c->rec);
        cairo_surface_destroy(c->surface);
        free(c); return TCL_ERROR;
    }

    if (!ctx_store(c)) {
        cairo_destroy(c->cr); cairo_surface_destroy(c->surface); free(c);
        Tcl_SetResult(interp, "too many contexts", TCL_STATIC);
        return TCL_ERROR;
    }
    Tcl_SetObjResult(interp, Tcl_NewIntObj(c->id));
    return TCL_OK;
}

/* tclmcairo destroy id */
static int CairoDestroyCmd(ClientData cd, Tcl_Interp *interp,
    int objc, Tcl_Obj *const objv[])
{
    (void)cd;
    if (objc < 3) { Tcl_WrongNumArgs(interp,2,objv,"id"); return TCL_ERROR; }
    int id; GET_INT(interp, objv[2], id);
    CairoCtx *c = ctx_find(id);
    if (!c) return TCL_OK;   /* already destroyed — silently ok */
    /* Release gradients */
    for (int i = 0; i < c->ngrads; i++)
        cairo_pattern_destroy(c->grads[i].pattern);
    c->ngrads = 0;
    cairo_destroy(c->cr);
    c->cr = NULL;
    /* file-mode: finish surface if not already done */
    if (!c->finished &&
        (c->mode == MODE_PDF || c->mode == MODE_SVG ||
         c->mode == MODE_PS  || c->mode == MODE_EPS)) {
        cairo_surface_finish(c->surface);
    }
    if (c->rec && c->rec != c->surface) cairo_surface_destroy(c->rec);
    cairo_surface_destroy(c->surface);
    c->surface = NULL; c->rec = NULL;
    ctx_remove(id); free(c);
    return TCL_OK;
}

/* tclmcairo clear id r g b ?a? */
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

/* tclmcairo size id -> {w h} */
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

/* tclmcairo todata id -> bytearray ARGB32 */
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

/* ================================================================== */
/* tclmcairo topng id -> bytearray (PNG-komprimiert)                   */
/* Schreibt Surface in-memory als PNG; gibt PNG-Bytes zurück.         */
/* Für Netzwerk, Datenbank, Tk photo -data etc.                       */
/* ================================================================== */

typedef struct {
    unsigned char *buf;
    size_t         len;
    size_t         cap;
} PngBuf;

static cairo_status_t png_write_cb(void *closure,
    const unsigned char *data, unsigned int length)
{
    PngBuf *pb = (PngBuf*)closure;
    if (pb->len + length > pb->cap) {
        size_t newcap = pb->cap * 2 + length + 4096;
        unsigned char *nb = (unsigned char*)realloc(pb->buf, newcap);
        if (!nb) return CAIRO_STATUS_NO_MEMORY;
        pb->buf = nb; pb->cap = newcap;
    }
    memcpy(pb->buf + pb->len, data, length);
    pb->len += length;
    return CAIRO_STATUS_SUCCESS;
}

static int CairoToPngCmd(ClientData cd, Tcl_Interp *interp,
    int objc, Tcl_Obj *const objv[])
{
    (void)cd;
    if (objc < 3) { Tcl_WrongNumArgs(interp,2,objv,"id"); return TCL_ERROR; }
    int id; GET_INT(interp, objv[2], id);
    CairoCtx *c = ctx_find(id);
    if (!c) { Tcl_SetResult(interp,"invalid id",TCL_STATIC); return TCL_ERROR; }

    cairo_surface_t *surf = c->surface;
    int free_surf = 0;

    /* vector mode: erst in raster rendern */
    if (c->vector && c->rec) {
        surf = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, c->width, c->height);
        cairo_t *cr2 = cairo_create(surf);
        cairo_set_source_surface(cr2, c->rec, 0, 0);
        cairo_paint(cr2);
        cairo_destroy(cr2);
        free_surf = 1;
    }

    cairo_surface_flush(surf);

    PngBuf pb = {0};
    pb.cap = (size_t)(c->width * c->height * 4 + 4096);
    pb.buf = (unsigned char*)malloc(pb.cap);
    if (!pb.buf) {
        if (free_surf) cairo_surface_destroy(surf);
        Tcl_SetResult(interp,"out of memory",TCL_STATIC);
        return TCL_ERROR;
    }

    cairo_status_t st = cairo_surface_write_to_png_stream(surf, png_write_cb, &pb);
    if (free_surf) cairo_surface_destroy(surf);

    if (st != CAIRO_STATUS_SUCCESS) {
        free(pb.buf);
        Tcl_SetResult(interp,(char*)cairo_status_to_string(st),TCL_VOLATILE);
        return TCL_ERROR;
    }

    Tcl_SetObjResult(interp,
        Tcl_NewByteArrayObj(pb.buf, (Tcl_Size)pb.len));
    free(pb.buf);
    return TCL_OK;
}

/* ================================================================== */
/* tclmcairo image_data id bytes x y ?-width w? ?-height h? ?-alpha a? */
/* Lädt PNG aus Bytearray (nicht aus Datei) und zeichnet es.          */
/* ================================================================== */

typedef struct {
    const unsigned char *buf;
    size_t               len;
    size_t               pos;
} PngReadBuf;

static cairo_status_t png_read_cb(void *closure,
    unsigned char *data, unsigned int length)
{
    PngReadBuf *rb = (PngReadBuf*)closure;
    if (rb->pos + length > rb->len) return CAIRO_STATUS_READ_ERROR;
    memcpy(data, rb->buf + rb->pos, length);
    rb->pos += length;
    return CAIRO_STATUS_SUCCESS;
}

static int CairoImageDataCmd(ClientData cd, Tcl_Interp *interp,
    int objc, Tcl_Obj *const objv[])
{
    (void)cd;
    if (objc < 6) {
        Tcl_WrongNumArgs(interp,2,objv,
            "id bytes x y ?-width w? ?-height h? ?-alpha a?");
        return TCL_ERROR;
    }
    int id; GET_INT(interp, objv[2], id);
    CairoCtx *c = ctx_find(id);
    if (!c) { Tcl_SetResult(interp,"invalid id",TCL_STATIC); return TCL_ERROR; }

    Tcl_Size blen;
    const unsigned char *bdata = Tcl_GetByteArrayFromObj(objv[3], &blen);
    if (!bdata || blen < 8) {
        Tcl_SetResult(interp,"image_data: invalid PNG bytes",TCL_STATIC);
        return TCL_ERROR;
    }

    double x, y;
    GET_DOUBLE(interp, objv[4], x);
    GET_DOUBLE(interp, objv[5], y);

    double dest_w = -1, dest_h = -1, alpha = 1.0;
    for (int i = 6; i+1 < objc; i += 2) {
        const char *k = Tcl_GetString(objv[i]);
        if      (!strcmp(k,"-width"))  { GET_DOUBLE(interp,objv[i+1],dest_w); }
        else if (!strcmp(k,"-height")) { GET_DOUBLE(interp,objv[i+1],dest_h); }
        else if (!strcmp(k,"-alpha"))  { GET_DOUBLE(interp,objv[i+1],alpha);  }
    }

    PngReadBuf rb = { bdata, (size_t)blen, 0 };
    cairo_surface_t *img = cairo_image_surface_create_from_png_stream(
        png_read_cb, &rb);

    if (!img || cairo_surface_status(img) != CAIRO_STATUS_SUCCESS) {
        const char *err_msg = img ?
            cairo_status_to_string(cairo_surface_status(img)) :
            "cannot decode PNG data";
        Tcl_SetObjResult(interp, Tcl_ObjPrintf("%s", err_msg));
        if (img) cairo_surface_destroy(img);
        return TCL_ERROR;
    }

    int iw = cairo_image_surface_get_width(img);
    int ih = cairo_image_surface_get_height(img);

    cairo_save(c->cr);
    cairo_translate(c->cr, x, y);
    if (dest_w > 0 || dest_h > 0) {
        double sw = (dest_w > 0) ? dest_w/iw : dest_h/ih;
        double sh = (dest_h > 0) ? dest_h/ih : sw;
        if (dest_w > 0 && dest_h > 0) { sw = dest_w/iw; sh = dest_h/ih; }
        cairo_scale(c->cr, sw, sh);
    }
    cairo_set_source_surface(c->cr, img, 0, 0);
    cairo_paint_with_alpha(c->cr, alpha);
    cairo_restore(c->cr);
    cairo_surface_destroy(img);
    return TCL_OK;
}

/* tclmcairo save id filename */
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
            if (check_cairo(interp, cr2, "save png") != TCL_OK) {
                cairo_destroy(cr2); cairo_surface_destroy(img);
                return TCL_ERROR;
            }
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

/* ================================================================== */
/* tclmcairo newpage id  -- cairo_show_page (multi-page PDF/PS/SVG)    */
/* ================================================================== */
static int CairoNewPageCmd(ClientData cd, Tcl_Interp *interp,
    int objc, Tcl_Obj *const objv[])
{
    (void)cd;
    if (objc < 3) { Tcl_WrongNumArgs(interp,2,objv,"id"); return TCL_ERROR; }
    int id; GET_INT(interp, objv[2], id);
    CairoCtx *c = ctx_find(id);
    if (!c) { Tcl_SetResult(interp,"invalid id",TCL_STATIC); return TCL_ERROR; }
    if (c->mode != MODE_PDF && c->mode != MODE_SVG &&
        c->mode != MODE_PS  && c->mode != MODE_EPS) {
        Tcl_SetResult(interp,
            "newpage only valid for -mode pdf|svg|ps|eps", TCL_STATIC);
        return TCL_ERROR;
    }
    cairo_show_page(c->cr);
    return TCL_OK;
}

/* ================================================================== */
/* tclmcairo finish id  -- flush + close file-mode surface             */
/* ================================================================== */
static int CairoFinishCmd(ClientData cd, Tcl_Interp *interp,
    int objc, Tcl_Obj *const objv[])
{
    (void)cd;
    if (objc < 3) { Tcl_WrongNumArgs(interp,2,objv,"id"); return TCL_ERROR; }
    int id; GET_INT(interp, objv[2], id);
    CairoCtx *c = ctx_find(id);
    if (!c) { Tcl_SetResult(interp,"invalid id",TCL_STATIC); return TCL_ERROR; }
    if (!c->finished) {
        cairo_surface_flush(c->surface);
        if (c->mode == MODE_PDF || c->mode == MODE_SVG ||
            c->mode == MODE_PS  || c->mode == MODE_EPS) {
            cairo_surface_finish(c->surface);
        }
        c->finished = 1;
    }
    return TCL_OK;
}

/* ================================================================== */
/* tclmcairo push id  -- cairo_save                                    */
/* tclmcairo pop  id  -- cairo_restore                                 */
/* ================================================================== */
static int CairoPushCmd(ClientData cd, Tcl_Interp *interp,
    int objc, Tcl_Obj *const objv[])
{
    (void)cd;
    if (objc < 3) { Tcl_WrongNumArgs(interp,2,objv,"id"); return TCL_ERROR; }
    int id; GET_INT(interp, objv[2], id);
    CairoCtx *c = ctx_find(id);
    if (!c) { Tcl_SetResult(interp,"invalid id",TCL_STATIC); return TCL_ERROR; }
    cairo_save(c->cr);
    return TCL_OK;
}

static int CairoPopCmd(ClientData cd, Tcl_Interp *interp,
    int objc, Tcl_Obj *const objv[])
{
    (void)cd;
    if (objc < 3) { Tcl_WrongNumArgs(interp,2,objv,"id"); return TCL_ERROR; }
    int id; GET_INT(interp, objv[2], id);
    CairoCtx *c = ctx_find(id);
    if (!c) { Tcl_SetResult(interp,"invalid id",TCL_STATIC); return TCL_ERROR; }
    cairo_restore(c->cr);
    return TCL_OK;
}

/* ================================================================== */
/* tclmcairo clip_rect  id x y w h                                     */
/* tclmcairo clip_path  id svgdata                                     */
/* tclmcairo clip_reset id                                             */
/* ================================================================== */
static int CairoClipRectCmd(ClientData cd, Tcl_Interp *interp,
    int objc, Tcl_Obj *const objv[])
{
    (void)cd;
    if (objc < 7) { Tcl_WrongNumArgs(interp,2,objv,"id x y w h"); return TCL_ERROR; }
    int id; GET_INT(interp, objv[2], id);
    CairoCtx *c = ctx_find(id);
    if (!c) { Tcl_SetResult(interp,"invalid id",TCL_STATIC); return TCL_ERROR; }
    double x,y,w,h;
    GET_DOUBLE(interp,objv[3],x); GET_DOUBLE(interp,objv[4],y);
    GET_DOUBLE(interp,objv[5],w); GET_DOUBLE(interp,objv[6],h);
    cairo_rectangle(c->cr, x, y, w, h);
    cairo_clip(c->cr);
    return TCL_OK;
}

static int CairoClipPathCmd(ClientData cd, Tcl_Interp *interp,
    int objc, Tcl_Obj *const objv[])
{
    (void)cd;
    if (objc < 4) { Tcl_WrongNumArgs(interp,2,objv,"id svgdata"); return TCL_ERROR; }
    int id; GET_INT(interp, objv[2], id);
    CairoCtx *c = ctx_find(id);
    if (!c) { Tcl_SetResult(interp,"invalid id",TCL_STATIC); return TCL_ERROR; }
    const char *svgdata = Tcl_GetString(objv[3]);
    cairo_new_path(c->cr);
    apply_svg_path(c->cr, svgdata);
    cairo_clip(c->cr);
    return TCL_OK;
}

static int CairoClipResetCmd(ClientData cd, Tcl_Interp *interp,
    int objc, Tcl_Obj *const objv[])
{
    (void)cd;
    if (objc < 3) { Tcl_WrongNumArgs(interp,2,objv,"id"); return TCL_ERROR; }
    int id; GET_INT(interp, objv[2], id);
    CairoCtx *c = ctx_find(id);
    if (!c) { Tcl_SetResult(interp,"invalid id",TCL_STATIC); return TCL_ERROR; }
    cairo_reset_clip(c->cr);
    return TCL_OK;
}

/* ================================================================== */
/* tclmcairo image id filename x y ?-width w? ?-height h? ?-alpha a?  */
/* Loads PNG (always) and JPEG (if HAVE_LIBJPEG).                     */
/* In PDF/SVG mode: JPEG is embedded as MIME data (no re-encoding).   */
/* ================================================================== */

#ifdef HAVE_LIBJPEG
/* Error handler for libjpeg */
struct JpegErrMgr {
    struct jpeg_error_mgr pub;
    jmp_buf setjmp_buf;
    char msg[256];
};
static void jpeg_error_exit(j_common_ptr cinfo) {
    struct JpegErrMgr *err = (struct JpegErrMgr*)cinfo->err;
    (*cinfo->err->format_message)(cinfo, err->msg);
    longjmp(err->setjmp_buf, 1);
}

static cairo_surface_t *load_jpeg(const char *filename,
    unsigned char **raw_out, size_t *raw_size_out)
{
    FILE *fp = fopen(filename, "rb");
    if (!fp) return NULL;

    /* Read raw file bytes for MIME embedding */
    fseek(fp, 0, SEEK_END); long fsz = ftell(fp); rewind(fp);
    unsigned char *raw = (unsigned char*)malloc((size_t)fsz);
    if (!raw) { fclose(fp); return NULL; }
    if ((long)fread(raw, 1, (size_t)fsz, fp) != fsz) {
        free(raw); fclose(fp); return NULL;
    }
    rewind(fp);

    struct jpeg_decompress_struct cinfo;
    struct JpegErrMgr jerr;
    cinfo.err = jpeg_std_error(&jerr.pub);
    jerr.pub.error_exit = jpeg_error_exit;
    if (setjmp(jerr.setjmp_buf)) {
        jpeg_destroy_decompress(&cinfo);
        fclose(fp); free(raw); return NULL;
    }
    jpeg_create_decompress(&cinfo);
    jpeg_stdio_src(&cinfo, fp);
    jpeg_read_header(&cinfo, TRUE);
    cinfo.out_color_space = JCS_RGB;
    jpeg_start_decompress(&cinfo);

    int w = (int)cinfo.output_width;
    int h = (int)cinfo.output_height;
    int stride = cairo_format_stride_for_width(CAIRO_FORMAT_RGB24, w);
    unsigned char *pixels = (unsigned char*)calloc((size_t)(stride * h), 1);
    if (!pixels) {
        jpeg_destroy_decompress(&cinfo);
        fclose(fp); free(raw); return NULL;
    }

    while ((int)cinfo.output_scanline < h) {
        unsigned char *row = pixels + cinfo.output_scanline * stride;
        /* libjpeg gives RGB, Cairo needs BGRA (little-endian ARGB32) */
        unsigned char *tmp = (unsigned char*)malloc((size_t)(w * 3));
        if (!tmp) break;
        unsigned char *rp = tmp;
        jpeg_read_scanlines(&cinfo, &rp, 1);
        for (int x = 0; x < w; x++) {
            row[x*4+0] = tmp[x*3+2]; /* B */
            row[x*4+1] = tmp[x*3+1]; /* G */
            row[x*4+2] = tmp[x*3+0]; /* R */
            row[x*4+3] = 0xFF;       /* A */
        }
        free(tmp);
    }
    jpeg_finish_decompress(&cinfo);
    jpeg_destroy_decompress(&cinfo);
    fclose(fp);

    cairo_surface_t *surf = cairo_image_surface_create_for_data(
        pixels, CAIRO_FORMAT_ARGB32, w, h, stride);
    /* Attach raw JPEG for PDF/SVG MIME embedding (no re-encoding) */
    cairo_surface_set_mime_data(surf, CAIRO_MIME_TYPE_JPEG,
        raw, (unsigned long)fsz,
        free,  /* destroy callback */
        raw);
    /* pixels: must survive surface; attach via user data */
    static cairo_user_data_key_t px_key;
    cairo_surface_set_user_data(surf, &px_key, pixels,
        (cairo_destroy_func_t)free);

    if (raw_out)      *raw_out      = raw;
    if (raw_size_out) *raw_size_out = (size_t)fsz;
    return surf;
}
#endif /* HAVE_LIBJPEG */

static int CairoImageCmd(ClientData cd, Tcl_Interp *interp,
    int objc, Tcl_Obj *const objv[])
{
    (void)cd;
    if (objc < 6) {
        Tcl_WrongNumArgs(interp,2,objv,
            "id filename x y ?-width w? ?-height h? ?-alpha a?");
        return TCL_ERROR;
    }
    int id; GET_INT(interp, objv[2], id);
    CairoCtx *c = ctx_find(id);
    if (!c) { Tcl_SetResult(interp,"invalid id",TCL_STATIC); return TCL_ERROR; }

    const char *fname = Tcl_GetString(objv[3]);
    double x, y;
    GET_DOUBLE(interp, objv[4], x);
    GET_DOUBLE(interp, objv[5], y);

    double dest_w = -1, dest_h = -1, alpha = 1.0;
    for (int i = 6; i+1 < objc; i += 2) {
        const char *k = Tcl_GetString(objv[i]);
        if      (!strcmp(k,"-width"))  { GET_DOUBLE(interp,objv[i+1],dest_w); }
        else if (!strcmp(k,"-height")) { GET_DOUBLE(interp,objv[i+1],dest_h); }
        else if (!strcmp(k,"-alpha"))  { GET_DOUBLE(interp,objv[i+1],alpha);  }
    }

    /* Load image surface.
     * JPEG: load_jpeg() automatically attaches CAIRO_MIME_TYPE_JPEG —
     *       Cairo PDF/SVG backends embed the original JPEG bytes 1:1,
     *       no re-encoding, no quality loss.
     * PNG:  cairo_image_surface_create_from_png() — Cairo re-encodes
     *       as pixel data in PDF/SVG (CAIRO_MIME_TYPE_PNG is not
     *       honored by current Cairo PDF/SVG backends). */
    cairo_surface_t *img = NULL;
#ifdef HAVE_LIBJPEG
    const char *dot = strrchr(fname, '.');
    const char *ext = dot ? dot+1 : "";
    if (!strcasecmp(ext,"jpg") || !strcasecmp(ext,"jpeg")) {
        img = load_jpeg(fname, NULL, NULL);
    }
#endif
    if (!img) {
        img = cairo_image_surface_create_from_png(fname);
    }

    if (!img || cairo_surface_status(img) != CAIRO_STATUS_SUCCESS) {
        const char *err_str = img ?
            cairo_status_to_string(cairo_surface_status(img)) :
            "cannot load image";
        Tcl_SetObjResult(interp, Tcl_ObjPrintf("image load failed: %s: %s", fname, err_str));
        if (img) cairo_surface_destroy(img);
        return TCL_ERROR;
    }

    int iw = cairo_image_surface_get_width(img);
    int ih = cairo_image_surface_get_height(img);

    cairo_save(c->cr);
    cairo_translate(c->cr, x, y);

    if (dest_w > 0 || dest_h > 0) {
        double sw = (dest_w > 0) ? dest_w / iw : (dest_h / ih);
        double sh = (dest_h > 0) ? dest_h / ih : sw;
        if (dest_w > 0 && dest_h > 0) { sw = dest_w/iw; sh = dest_h/ih; }
        cairo_scale(c->cr, sw, sh);
    }

    cairo_set_source_surface(c->cr, img, 0, 0);
    cairo_paint_with_alpha(c->cr, alpha);
    cairo_restore(c->cr);
    cairo_surface_destroy(img);
    return TCL_OK;
}

/* ================================================================== */
/* tclmcairo blit dst_id src_id x y ?-alpha a? ?-width w? ?-height h? */
/* Composites src context onto dst context at (x,y).                  */
/* Both raster and vector sources supported.                          */
/* ================================================================== */
static int CairoBlitCmd(ClientData cd, Tcl_Interp *interp,
    int objc, Tcl_Obj *const objv[])
{
    (void)cd;
    if (objc < 6) {
        Tcl_WrongNumArgs(interp,2,objv,"dst_id src_id x y ?-alpha a? ?-width w? ?-height h?");
        return TCL_ERROR;
    }
    int dst_id, src_id;
    GET_INT(interp, objv[2], dst_id);
    GET_INT(interp, objv[3], src_id);
    CairoCtx *dst = ctx_find(dst_id);
    CairoCtx *src = ctx_find(src_id);
    if (!dst) { Tcl_SetResult(interp,"invalid dst_id",TCL_STATIC); return TCL_ERROR; }
    if (!src) { Tcl_SetResult(interp,"invalid src_id",TCL_STATIC); return TCL_ERROR; }
    if (dst_id == src_id) {
        Tcl_SetResult(interp,"blit: dst and src must be different contexts",TCL_STATIC);
        return TCL_ERROR;
    }

    double x, y;
    GET_DOUBLE(interp, objv[4], x);
    GET_DOUBLE(interp, objv[5], y);

    double alpha = 1.0, dest_w = -1, dest_h = -1;
    for (int i = 6; i+1 < objc; i += 2) {
        const char *k = Tcl_GetString(objv[i]);
        if      (!strcmp(k,"-alpha"))  { GET_DOUBLE(interp,objv[i+1],alpha);  }
        else if (!strcmp(k,"-width"))  { GET_DOUBLE(interp,objv[i+1],dest_w); }
        else if (!strcmp(k,"-height")) { GET_DOUBLE(interp,objv[i+1],dest_h); }
    }

    /* Für vector source: zuerst in Raster rendern */
    cairo_surface_t *src_surf = NULL;
    int free_src = 0;

    if (src->vector && src->rec) {
        /* Recording surface → temp raster für blit */
        cairo_surface_t *tmp = cairo_image_surface_create(
            CAIRO_FORMAT_ARGB32, src->width, src->height);
        cairo_t *cr2 = cairo_create(tmp);
        cairo_set_source_surface(cr2, src->rec, 0, 0);
        cairo_paint(cr2);
        cairo_destroy(cr2);
        src_surf = tmp;
        free_src = 1;
    } else if (!src->vector) {
        cairo_surface_flush(src->surface);
        src_surf = src->surface;
    } else {
        /* file-mode vector: nicht direkt blittbar */
        Tcl_SetResult(interp,
            "blit: src in file-mode (pdf|svg|ps|eps) not supported",
            TCL_STATIC);
        return TCL_ERROR;
    }

    cairo_save(dst->cr);
    cairo_translate(dst->cr, x, y);

    if (dest_w > 0 || dest_h > 0) {
        double sw = (dest_w > 0) ? dest_w / src->width  : (dest_h / src->height);
        double sh = (dest_h > 0) ? dest_h / src->height : sw;
        if (dest_w > 0 && dest_h > 0) { sw = dest_w/src->width; sh = dest_h/src->height; }
        cairo_scale(dst->cr, sw, sh);
    }

    cairo_set_source_surface(dst->cr, src_surf, 0, 0);
    cairo_paint_with_alpha(dst->cr, alpha);
    cairo_restore(dst->cr);

    if (free_src) cairo_surface_destroy(src_surf);
    return TCL_OK;
}

/* tclmcairo rect id x y w h ?opts? */
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

/* tclmcairo line id x1 y1 x2 y2 ?opts? */
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

/* tclmcairo circle id cx cy r ?opts? */
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

/* tclmcairo ellipse id cx cy rx ry ?opts? */
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

/* tclmcairo arc id cx cy r start_deg end_deg ?opts? */
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

/* tclmcairo poly id x1 y1 x2 y2 ... ?opts? */
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

/* tclmcairo path id svgdata ?opts? */
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

/* tclmcairo text id x y string ?opts? */
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
    double ca = o.has_color?o.color_a:1.0;
    cairo_move_to(c->cr, tx, ty);

    if (o.outline) {
        /* -outline 1: text_path statt show_text
         * → font-unabhängiges SVG, fill/stroke/gradient möglich */
        cairo_text_path(c->cr, text);
        if (!o.has_fill && !o.has_fillname && !o.has_stroke) {
            /* Fallback: Farbe aus -color */
            o.has_fill = 1;
            o.fill_r = r; o.fill_g = g2; o.fill_b = b; o.fill_a = ca;
        }
        draw_fill_stroke(c->cr, &o, c);
    } else {
        /* Standard: cairo_show_text → SVG <text> Element */
        cairo_set_source_rgba(c->cr, r, g2, b, ca * o.alpha);
        cairo_show_text(c->cr, text);
    }
    return TCL_OK;
}

/* ================================================================== */
/* tclmcairo text_path id x y string ?opts?                            */
/* Text als Pfad: ermöglicht -fill, -stroke, -fillname (Gradient)    */
/* ================================================================== */
static int CairoTextPathCmd(ClientData cd, Tcl_Interp *interp,
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

    /* Anchor-Berechnung wie CairoTextCmd */
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

    cairo_move_to(c->cr, tx, ty);
    cairo_text_path(c->cr, text);   /* Text als Pfad statt show_text */

    /* Standard: weißer Fill wenn keine Option angegeben */
    if (!o.has_fill && !o.has_fillname && !o.has_stroke) {
        o.has_fill = 1;
        o.fill_r = o.fill_g = o.fill_b = 1.0; o.fill_a = 1.0;
    }
    draw_fill_stroke(c->cr, &o, c);
    return TCL_OK;
}
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

/* tclmcairo transform id -translate x y | -scale sx sy | -rotate deg |
 *                        -matrix a b c d tx ty | -get | -reset         */
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
    } else if (!strcmp(op,"-matrix") && objc >= 10) {
        /* -matrix a b c d tx ty  (affine 2x3) */
        cairo_matrix_t m;
        GET_DOUBLE(interp,objv[4],m.xx); GET_DOUBLE(interp,objv[5],m.yx);
        GET_DOUBLE(interp,objv[6],m.xy); GET_DOUBLE(interp,objv[7],m.yy);
        GET_DOUBLE(interp,objv[8],m.x0); GET_DOUBLE(interp,objv[9],m.y0);
        cairo_transform(c->cr, &m);
    } else if (!strcmp(op,"-get")) {
        /* Returns current CTM as {xx yx xy yy x0 y0} */
        cairo_matrix_t m;
        cairo_get_matrix(c->cr, &m);
        Tcl_Obj *lst = Tcl_NewListObj(0, NULL);
        Tcl_ListObjAppendElement(interp, lst, Tcl_NewDoubleObj(m.xx));
        Tcl_ListObjAppendElement(interp, lst, Tcl_NewDoubleObj(m.yx));
        Tcl_ListObjAppendElement(interp, lst, Tcl_NewDoubleObj(m.xy));
        Tcl_ListObjAppendElement(interp, lst, Tcl_NewDoubleObj(m.yy));
        Tcl_ListObjAppendElement(interp, lst, Tcl_NewDoubleObj(m.x0));
        Tcl_ListObjAppendElement(interp, lst, Tcl_NewDoubleObj(m.y0));
        Tcl_SetObjResult(interp, lst);
    } else {
        Tcl_SetResult(interp,
            "transform: -translate x y | -scale sx sy | -rotate deg"
            " | -matrix xx yx xy yy x0 y0 | -get | -reset",
            TCL_STATIC);
        return TCL_ERROR;
    }
    return TCL_OK;
}

/* tclmcairo gradient_linear id name x1 y1 x2 y2 stops
 * tclmcairo gradient_radial  id name cx cy r stops
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

/* tclmcairo operator id NAME                                         */
/* Sets the compositing operator. NAME is the Cairo suffix without    */
/* CAIRO_OPERATOR_: OVER SOURCE CLEAR IN OUT ATOP DEST DEST_OVER     */
/* DEST_IN DEST_OUT DEST_ATOP XOR ADD SATURATE MULTIPLY SCREEN        */
/* OVERLAY DARKEN LIGHTEN COLOR_DODGE COLOR_BURN HARD_LIGHT SOFT_LIGHT*/
/* DIFFERENCE EXCLUSION HSL_HUE HSL_SATURATION HSL_COLOR HSL_LUMINOSITY*/
/* ================================================================== */
static int CairoOperatorCmd(ClientData cd, Tcl_Interp *interp,
    int objc, Tcl_Obj *const objv[])
{
    (void)cd;
    if (objc < 4) {
        Tcl_WrongNumArgs(interp,2,objv,"id OPERATOR");
        return TCL_ERROR;
    }
    int id; GET_INT(interp, objv[2], id);
    CairoCtx *c = ctx_find(id);
    if (!c) { Tcl_SetResult(interp,"invalid id",TCL_STATIC); return TCL_ERROR; }

    struct { const char *name; cairo_operator_t op; } ops[] = {
        {"OVER",          CAIRO_OPERATOR_OVER},
        {"SOURCE",        CAIRO_OPERATOR_SOURCE},
        {"CLEAR",         CAIRO_OPERATOR_CLEAR},
        {"IN",            CAIRO_OPERATOR_IN},
        {"OUT",           CAIRO_OPERATOR_OUT},
        {"ATOP",          CAIRO_OPERATOR_ATOP},
        {"DEST",          CAIRO_OPERATOR_DEST},
        {"DEST_OVER",     CAIRO_OPERATOR_DEST_OVER},
        {"DEST_IN",       CAIRO_OPERATOR_DEST_IN},
        {"DEST_OUT",      CAIRO_OPERATOR_DEST_OUT},
        {"DEST_ATOP",     CAIRO_OPERATOR_DEST_ATOP},
        {"XOR",           CAIRO_OPERATOR_XOR},
        {"ADD",           CAIRO_OPERATOR_ADD},
        {"SATURATE",      CAIRO_OPERATOR_SATURATE},
        {"MULTIPLY",      CAIRO_OPERATOR_MULTIPLY},
        {"SCREEN",        CAIRO_OPERATOR_SCREEN},
        {"OVERLAY",       CAIRO_OPERATOR_OVERLAY},
        {"DARKEN",        CAIRO_OPERATOR_DARKEN},
        {"LIGHTEN",       CAIRO_OPERATOR_LIGHTEN},
        {"COLOR_DODGE",   CAIRO_OPERATOR_COLOR_DODGE},
        {"COLOR_BURN",    CAIRO_OPERATOR_COLOR_BURN},
        {"HARD_LIGHT",    CAIRO_OPERATOR_HARD_LIGHT},
        {"SOFT_LIGHT",    CAIRO_OPERATOR_SOFT_LIGHT},
        {"DIFFERENCE",    CAIRO_OPERATOR_DIFFERENCE},
        {"EXCLUSION",     CAIRO_OPERATOR_EXCLUSION},
        {"HSL_HUE",       CAIRO_OPERATOR_HSL_HUE},
        {"HSL_SATURATION",CAIRO_OPERATOR_HSL_SATURATION},
        {"HSL_COLOR",     CAIRO_OPERATOR_HSL_COLOR},
        {"HSL_LUMINOSITY",CAIRO_OPERATOR_HSL_LUMINOSITY},
        {NULL, 0}
    };

    const char *name = Tcl_GetString(objv[3]);
    for (int i = 0; ops[i].name; i++) {
        if (!strcasecmp(name, ops[i].name)) {
            cairo_set_operator(c->cr, ops[i].op);
            return TCL_OK;
        }
    }
    Tcl_SetObjResult(interp, Tcl_ObjPrintf("%s\" — use OVER SOURCE CLEAR XOR MULTIPLY SCREEN OVERLAY "
        "DARKEN LIGHTEN DIFFERENCE EXCLUSION etc.", name));
    return TCL_ERROR;
}

/* ================================================================== */
/* tclmcairo user_to_device   id x y  -> {dx dy}                     */
/* tclmcairo device_to_user   id dx dy -> {x y}                      */
/* Maps coordinates through the current transformation matrix.        */
/* Essential for interactive apps: mouse position under transforms.   */
/* ================================================================== */
static int CairoUserToDeviceCmd(ClientData cd, Tcl_Interp *interp,
    int objc, Tcl_Obj *const objv[])
{
    (void)cd;
    if (objc != 5) { Tcl_WrongNumArgs(interp,2,objv,"id x y"); return TCL_ERROR; }
    int id; GET_INT(interp, objv[2], id);
    CairoCtx *c = ctx_find(id);
    if (!c) { Tcl_SetResult(interp,"invalid id",TCL_STATIC); return TCL_ERROR; }
    double x, y;
    GET_DOUBLE(interp, objv[3], x); GET_DOUBLE(interp, objv[4], y);
    cairo_user_to_device(c->cr, &x, &y);
    Tcl_Obj *lst = Tcl_NewListObj(0, NULL);
    Tcl_ListObjAppendElement(interp, lst, Tcl_NewDoubleObj(x));
    Tcl_ListObjAppendElement(interp, lst, Tcl_NewDoubleObj(y));
    Tcl_SetObjResult(interp, lst);
    return TCL_OK;
}

static int CairoDeviceToUserCmd(ClientData cd, Tcl_Interp *interp,
    int objc, Tcl_Obj *const objv[])
{
    (void)cd;
    if (objc != 5) { Tcl_WrongNumArgs(interp,2,objv,"id dx dy"); return TCL_ERROR; }
    int id; GET_INT(interp, objv[2], id);
    CairoCtx *c = ctx_find(id);
    if (!c) { Tcl_SetResult(interp,"invalid id",TCL_STATIC); return TCL_ERROR; }
    double x, y;
    GET_DOUBLE(interp, objv[3], x); GET_DOUBLE(interp, objv[4], y);
    cairo_device_to_user(c->cr, &x, &y);
    Tcl_Obj *lst = Tcl_NewListObj(0, NULL);
    Tcl_ListObjAppendElement(interp, lst, Tcl_NewDoubleObj(x));
    Tcl_ListObjAppendElement(interp, lst, Tcl_NewDoubleObj(y));
    Tcl_SetObjResult(interp, lst);
    return TCL_OK;
}

/* ================================================================== */
/* tclmcairo arc_negative id cx cy r start end ?opts?                 */
/* Like arc but counter-clockwise (cairo_arc_negative).               */
/* ================================================================== */
static int CairoArcNegativeCmd(ClientData cd, Tcl_Interp *interp,
    int objc, Tcl_Obj *const objv[])
{
    (void)cd;
    if (objc < 8) {
        Tcl_WrongNumArgs(interp,2,objv,"id cx cy r start end ?opts?");
        return TCL_ERROR;
    }
    int id; GET_INT(interp, objv[2], id);
    CairoCtx *c = ctx_find(id);
    if (!c) { Tcl_SetResult(interp,"invalid id",TCL_STATIC); return TCL_ERROR; }
    double cx, cy, r, a1, a2;
    GET_DOUBLE(interp,objv[3],cx); GET_DOUBLE(interp,objv[4],cy);
    GET_DOUBLE(interp,objv[5],r);
    GET_DOUBLE(interp,objv[6],a1); GET_DOUBLE(interp,objv[7],a2);
    DrawOpts o; if (!parse_opts(interp,objc,objv,8,&o)) return TCL_ERROR;
    cairo_arc_negative(c->cr, cx, cy, r, a1*M_PI/180.0, a2*M_PI/180.0);
    draw_fill_stroke(c->cr, &o, c);
    return TCL_OK;
}

/* ================================================================== */
/* tclmcairo recording_bbox id  -> {x y w h}                         */
/* Returns the ink bounding box of a vector (recording) context.      */
/* ================================================================== */
static int CairoRecordingBboxCmd(ClientData cd, Tcl_Interp *interp,
    int objc, Tcl_Obj *const objv[])
{
    (void)cd;
    if (objc < 3) { Tcl_WrongNumArgs(interp,2,objv,"id"); return TCL_ERROR; }
    int id; GET_INT(interp, objv[2], id);
    CairoCtx *c = ctx_find(id);
    if (!c) { Tcl_SetResult(interp,"invalid id",TCL_STATIC); return TCL_ERROR; }

    cairo_surface_t *surf = (c->rec && c->rec != c->surface) ? c->rec : c->surface;
    if (cairo_surface_get_type(surf) != CAIRO_SURFACE_TYPE_RECORDING) {
        Tcl_SetResult(interp,
            "recording_bbox: context is not in vector mode", TCL_STATIC);
        return TCL_ERROR;
    }
    cairo_surface_flush(surf);
    double x, y, w, h;
    cairo_recording_surface_ink_extents(surf, &x, &y, &w, &h);
    Tcl_Obj *lst = Tcl_NewListObj(0, NULL);
    Tcl_ListObjAppendElement(interp, lst, Tcl_NewDoubleObj(x));
    Tcl_ListObjAppendElement(interp, lst, Tcl_NewDoubleObj(y));
    Tcl_ListObjAppendElement(interp, lst, Tcl_NewDoubleObj(w));
    Tcl_ListObjAppendElement(interp, lst, Tcl_NewDoubleObj(h));
    Tcl_SetObjResult(interp, lst);
    return TCL_OK;
}


/* ================================================================== */
/* Ensemble dispatcher                                                */
/* ================================================================== */

/* tclmcairo gradient_extend id name extend                           */
/* Sets the extend mode of a named gradient/pattern.                  */
/* extend: none | pad (default) | repeat | reflect                    */
/* ================================================================== */
static int CairoGradientExtendCmd(ClientData cd, Tcl_Interp *interp,
    int objc, Tcl_Obj *const objv[])
{
    (void)cd;
    if (objc < 5) {
        Tcl_WrongNumArgs(interp,2,objv,"id name none|pad|repeat|reflect");
        return TCL_ERROR;
    }
    int id; GET_INT(interp, objv[2], id);
    CairoCtx *c = ctx_find(id);
    if (!c) { Tcl_SetResult(interp,"invalid id",TCL_STATIC); return TCL_ERROR; }
    const char *name = Tcl_GetString(objv[3]);
    cairo_pattern_t *pat = grad_find(c, name);
    if (!pat) {
        Tcl_SetObjResult(interp, Tcl_ObjPrintf("%s\"", name));
        return TCL_ERROR;
    }
    const char *ext = Tcl_GetString(objv[4]);
    cairo_extend_t mode;
    if      (!strcmp(ext,"none"))    mode = CAIRO_EXTEND_NONE;
    else if (!strcmp(ext,"pad"))     mode = CAIRO_EXTEND_PAD;
    else if (!strcmp(ext,"repeat"))  mode = CAIRO_EXTEND_REPEAT;
    else if (!strcmp(ext,"reflect")) mode = CAIRO_EXTEND_REFLECT;
    else {
        Tcl_SetObjResult(interp, Tcl_ObjPrintf("%s\" — use none|pad|repeat|reflect", ext));
        return TCL_ERROR;
    }
    cairo_pattern_set_extend(pat, mode);
    return TCL_OK;
}

/* ================================================================== */
/* tclmcairo gradient_filter id name filter                           */
/* Sets the filter/interpolation for image patterns.                  */
/* filter: fast | good | best | nearest | bilinear                    */
/* ================================================================== */
static int CairoGradientFilterCmd(ClientData cd, Tcl_Interp *interp,
    int objc, Tcl_Obj *const objv[])
{
    (void)cd;
    if (objc < 5) {
        Tcl_WrongNumArgs(interp,2,objv,"id name fast|good|best|nearest|bilinear");
        return TCL_ERROR;
    }
    int id; GET_INT(interp, objv[2], id);
    CairoCtx *c = ctx_find(id);
    if (!c) { Tcl_SetResult(interp,"invalid id",TCL_STATIC); return TCL_ERROR; }
    const char *name = Tcl_GetString(objv[3]);
    cairo_pattern_t *pat = grad_find(c, name);
    if (!pat) {
        Tcl_SetObjResult(interp, Tcl_ObjPrintf("%s\"", name));
        return TCL_ERROR;
    }
    const char *flt = Tcl_GetString(objv[4]);
    cairo_filter_t mode;
    if      (!strcmp(flt,"fast"))     mode = CAIRO_FILTER_FAST;
    else if (!strcmp(flt,"good"))     mode = CAIRO_FILTER_GOOD;
    else if (!strcmp(flt,"best"))     mode = CAIRO_FILTER_BEST;
    else if (!strcmp(flt,"nearest"))  mode = CAIRO_FILTER_NEAREST;
    else if (!strcmp(flt,"bilinear")) mode = CAIRO_FILTER_BILINEAR;
    else {
        Tcl_SetObjResult(interp, Tcl_ObjPrintf("%s\" — use fast|good|best|nearest|bilinear", flt));
        return TCL_ERROR;
    }
    cairo_pattern_set_filter(pat, mode);
    return TCL_OK;
}

/* ================================================================== */
/* tclmcairo paint id ?alpha?                                         */
/* Paints the current source over the entire surface.                 */
/* With alpha: paints with given opacity (0.0-1.0).                   */
/* ================================================================== */
static int CairoPaintCmd(ClientData cd, Tcl_Interp *interp,
    int objc, Tcl_Obj *const objv[])
{
    (void)cd;
    if (objc < 3) { Tcl_WrongNumArgs(interp,2,objv,"id ?alpha?"); return TCL_ERROR; }
    int id; GET_INT(interp, objv[2], id);
    CairoCtx *c = ctx_find(id);
    if (!c) { Tcl_SetResult(interp,"invalid id",TCL_STATIC); return TCL_ERROR; }
    if (objc >= 4) {
        double alpha; GET_DOUBLE(interp, objv[3], alpha);
        cairo_paint_with_alpha(c->cr, alpha);
    } else {
        cairo_paint(c->cr);
    }
    return TCL_OK;
}

/* ================================================================== */
/* tclmcairo set_source id -color {r g b ?a?} | -gradient name        */
/* Sets the current source pattern without drawing.                   */
/* Useful before paint, or for advanced compositing.                  */
/* ================================================================== */
static int CairoSetSourceCmd(ClientData cd, Tcl_Interp *interp,
    int objc, Tcl_Obj *const objv[])
{
    (void)cd;
    if (objc < 5) {
        Tcl_WrongNumArgs(interp,2,objv,"id -color {r g b ?a?} | -gradient name");
        return TCL_ERROR;
    }
    int id; GET_INT(interp, objv[2], id);
    CairoCtx *c = ctx_find(id);
    if (!c) { Tcl_SetResult(interp,"invalid id",TCL_STATIC); return TCL_ERROR; }
    const char *opt = Tcl_GetString(objv[3]);
    if (!strcmp(opt, "-color")) {
        double r=0,g=0,b=0,a=1;
        Tcl_Size n; Tcl_Obj **elems;
        if (Tcl_ListObjGetElements(interp,objv[4],&n,&elems) != TCL_OK) return TCL_ERROR;
        if (n < 3) { Tcl_SetResult(interp,"set_source: color needs {r g b ?a?}",TCL_STATIC); return TCL_ERROR; }
        Tcl_GetDoubleFromObj(interp,elems[0],&r);
        Tcl_GetDoubleFromObj(interp,elems[1],&g);
        Tcl_GetDoubleFromObj(interp,elems[2],&b);
        if (n >= 4) Tcl_GetDoubleFromObj(interp,elems[3],&a);
        cairo_set_source_rgba(c->cr, r, g, b, a);
    } else if (!strcmp(opt, "-gradient")) {
        const char *name = Tcl_GetString(objv[4]);
        cairo_pattern_t *pat = grad_find(c, name);
        if (!pat) {
            Tcl_SetObjResult(interp, Tcl_ObjPrintf("%s\"", name));
            return TCL_ERROR;
        }
        cairo_set_source(c->cr, pat);
    } else {
        Tcl_SetObjResult(interp, Tcl_ObjPrintf("%s\" — use -color or -gradient", opt));
        return TCL_ERROR;
    }
    return TCL_OK;
}



/* ================================================================== */
/* tclmcairo font_options id ?-antialias default|none|gray|subpixel?  */
/*                            ?-hint_style none|slight|medium|full?   */
/*                            ?-hint_metrics on|off|default?          */
/* Sets font rendering options. Called before text commands.          */
/* Without args: returns current settings as dict.                    */
/* ================================================================== */
static int CairoFontOptionsCmd(ClientData cd, Tcl_Interp *interp,
    int objc, Tcl_Obj *const objv[])
{
    (void)cd;
    if (objc < 3) { Tcl_WrongNumArgs(interp,2,objv,"id ?-option value?..."); return TCL_ERROR; }
    int id; GET_INT(interp, objv[2], id);
    CairoCtx *c = ctx_find(id);
    if (!c) { Tcl_SetResult(interp,"invalid id",TCL_STATIC); return TCL_ERROR; }

    cairo_font_options_t *fo = cairo_font_options_create();
    cairo_get_font_options(c->cr, fo);

    if (objc == 3) {
        /* No args — return current settings as flat list */
        const char *aa_names[] = {"default","none","gray","subpixel","fast","good","best"};
        const char *hs_names[] = {"default","none","slight","medium","full"};
        const char *hm_names[] = {"default","off","on"};
        cairo_antialias_t aa = cairo_font_options_get_antialias(fo);
        cairo_hint_style_t hs = cairo_font_options_get_hint_style(fo);
        cairo_hint_metrics_t hm = cairo_font_options_get_hint_metrics(fo);
        Tcl_Obj *lst = Tcl_NewListObj(0, NULL);
        Tcl_ListObjAppendElement(interp, lst, Tcl_NewStringObj("-antialias",-1));
        Tcl_ListObjAppendElement(interp, lst,
            Tcl_NewStringObj(aa < 7 ? aa_names[aa] : "default",-1));
        Tcl_ListObjAppendElement(interp, lst, Tcl_NewStringObj("-hint_style",-1));
        Tcl_ListObjAppendElement(interp, lst,
            Tcl_NewStringObj(hs < 5 ? hs_names[hs] : "default",-1));
        Tcl_ListObjAppendElement(interp, lst, Tcl_NewStringObj("-hint_metrics",-1));
        Tcl_ListObjAppendElement(interp, lst,
            Tcl_NewStringObj(hm < 3 ? hm_names[hm] : "default",-1));
        cairo_font_options_destroy(fo);
        Tcl_SetObjResult(interp, lst);
        return TCL_OK;
    }

    for (int i = 3; i+1 < objc; i += 2) {
        const char *k = Tcl_GetString(objv[i]);
        const char *v = Tcl_GetString(objv[i+1]);
        if (!strcmp(k,"-antialias")) {
            cairo_antialias_t aa;
            if      (!strcmp(v,"default"))  aa = CAIRO_ANTIALIAS_DEFAULT;
            else if (!strcmp(v,"none"))     aa = CAIRO_ANTIALIAS_NONE;
            else if (!strcmp(v,"gray"))     aa = CAIRO_ANTIALIAS_GRAY;
            else if (!strcmp(v,"subpixel")) aa = CAIRO_ANTIALIAS_SUBPIXEL;
            else if (!strcmp(v,"fast"))     aa = CAIRO_ANTIALIAS_FAST;
            else if (!strcmp(v,"good"))     aa = CAIRO_ANTIALIAS_GOOD;
            else if (!strcmp(v,"best"))     aa = CAIRO_ANTIALIAS_BEST;
            else {
                cairo_font_options_destroy(fo);
                Tcl_SetObjResult(interp, Tcl_ObjPrintf("invalid -antialias: %s (default|none|gray|subpixel|fast|good|best)", v));
                return TCL_ERROR;
            }
            cairo_font_options_set_antialias(fo, aa);
        } else if (!strcmp(k,"-hint_style")) {
            cairo_hint_style_t hs;
            if      (!strcmp(v,"default")) hs = CAIRO_HINT_STYLE_DEFAULT;
            else if (!strcmp(v,"none"))    hs = CAIRO_HINT_STYLE_NONE;
            else if (!strcmp(v,"slight"))  hs = CAIRO_HINT_STYLE_SLIGHT;
            else if (!strcmp(v,"medium"))  hs = CAIRO_HINT_STYLE_MEDIUM;
            else if (!strcmp(v,"full"))    hs = CAIRO_HINT_STYLE_FULL;
            else {
                cairo_font_options_destroy(fo);
                Tcl_SetObjResult(interp, Tcl_ObjPrintf("invalid -hint_style: %s (default|none|slight|medium|full)", v));
                return TCL_ERROR;
            }
            cairo_font_options_set_hint_style(fo, hs);
        } else if (!strcmp(k,"-hint_metrics")) {
            cairo_hint_metrics_t hm;
            if      (!strcmp(v,"default")) hm = CAIRO_HINT_METRICS_DEFAULT;
            else if (!strcmp(v,"on"))      hm = CAIRO_HINT_METRICS_ON;
            else if (!strcmp(v,"off"))     hm = CAIRO_HINT_METRICS_OFF;
            else {
                cairo_font_options_destroy(fo);
                Tcl_SetObjResult(interp, Tcl_ObjPrintf("invalid -hint_metrics: %s (default|on|off)", v));
                return TCL_ERROR;
            }
            cairo_font_options_set_hint_metrics(fo, hm);
        } else {
            cairo_font_options_destroy(fo);
            Tcl_SetObjResult(interp, Tcl_ObjPrintf("%s\"", k));
            return TCL_ERROR;
        }
    }
    cairo_set_font_options(c->cr, fo);
    cairo_font_options_destroy(fo);
    return TCL_OK;
}

/* ================================================================== */
/* tclmcairo path_get id  -> SVG path string                          */
/* Returns the current path as an SVG path string (M L C Q Z).        */
/* Useful for debugging, path inspection, or re-using paths.          */
/* ================================================================== */
static int CairoPathGetCmd(ClientData cd, Tcl_Interp *interp,
    int objc, Tcl_Obj *const objv[])
{
    (void)cd;
    if (objc < 3) { Tcl_WrongNumArgs(interp,2,objv,"id"); return TCL_ERROR; }
    int id; GET_INT(interp, objv[2], id);
    CairoCtx *c = ctx_find(id);
    if (!c) { Tcl_SetResult(interp,"invalid id",TCL_STATIC); return TCL_ERROR; }

    cairo_path_t *path = cairo_copy_path(c->cr);
    if (!path || path->status != CAIRO_STATUS_SUCCESS) {
        if (path) cairo_path_destroy(path);
        Tcl_SetResult(interp,"path_get: failed to copy path",TCL_STATIC);
        return TCL_ERROR;
    }

    Tcl_DString ds;
    Tcl_DStringInit(&ds);
    int first = 1;

    for (int i = 0; i < path->num_data; ) {
        cairo_path_data_t *d = &path->data[i];
        if (!first) Tcl_DStringAppend(&ds, " ", 1);
        first = 0;
        char buf[256];
        switch (d->header.type) {
        case CAIRO_PATH_MOVE_TO:
            snprintf(buf, sizeof(buf), "M %.6g %.6g",
                d[1].point.x, d[1].point.y);
            break;
        case CAIRO_PATH_LINE_TO:
            snprintf(buf, sizeof(buf), "L %.6g %.6g",
                d[1].point.x, d[1].point.y);
            break;
        case CAIRO_PATH_CURVE_TO:
            snprintf(buf, sizeof(buf), "C %.6g %.6g %.6g %.6g %.6g %.6g",
                d[1].point.x, d[1].point.y,
                d[2].point.x, d[2].point.y,
                d[3].point.x, d[3].point.y);
            break;
        case CAIRO_PATH_CLOSE_PATH:
            snprintf(buf, sizeof(buf), "Z");
            break;
        default:
            buf[0] = '\0';
        }
        if (buf[0]) Tcl_DStringAppend(&ds, buf, -1);
        i += d->header.length;
    }

    cairo_path_destroy(path);
    Tcl_DStringResult(interp, &ds);
    return TCL_OK;
}

/* ================================================================== */
/* tclmcairo surface_copy id ?w h?  -> new context id                 */
/* Creates a new raster context compatible with the source.           */
/* If w h omitted: same size as source.                               */
/* The new context starts blank (transparent/black).                  */
/* ================================================================== */
static int CairoSurfaceCopyCmd(ClientData cd, Tcl_Interp *interp,
    int objc, Tcl_Obj *const objv[])
{
    (void)cd;
    if (objc < 3) { Tcl_WrongNumArgs(interp,2,objv,"id ?w h?"); return TCL_ERROR; }
    int id; GET_INT(interp, objv[2], id);
    CairoCtx *src = ctx_find(id);
    if (!src) { Tcl_SetResult(interp,"invalid id",TCL_STATIC); return TCL_ERROR; }

    int w = src->width, h = src->height;
    if (objc >= 5) {
        GET_INT(interp, objv[3], w);
        GET_INT(interp, objv[4], h);
    }

    CairoCtx *c = (CairoCtx*)calloc(1, sizeof(CairoCtx));
    c->id = g_next_id++;
    c->width = w; c->height = h;
    c->mode = MODE_RASTER;
    c->fmt  = src->fmt;
    c->ngrads = 0; c->finished = 0;
    c->vector = 0;

    /* Use create_similar_image for best compatibility */
    cairo_surface_t *ref = src->vector ? src->rec : src->surface;
    c->surface = cairo_surface_create_similar_image(ref, src->fmt, w, h);
    if (cairo_surface_status(c->surface) != CAIRO_STATUS_SUCCESS) {
        /* Fallback: plain image surface */
        cairo_surface_destroy(c->surface);
        c->surface = cairo_image_surface_create(src->fmt, w, h);
    }
    c->cr   = cairo_create(c->surface);
    c->data = cairo_image_surface_get_data(c->surface);
    c->rec  = NULL;

    if (!ctx_store(c)) {
        cairo_destroy(c->cr);
        cairo_surface_destroy(c->surface);
        free(c);
        Tcl_SetResult(interp,"too many contexts",TCL_STATIC);
        return TCL_ERROR;
    }
    Tcl_SetObjResult(interp, Tcl_NewIntObj(c->id));
    return TCL_OK;
}


/* ================================================================== */
/* Low-level path commands — for porting Cairo C examples             */
/*                                                                    */
/* tclmcairo move_to      id x y                                     */
/* tclmcairo line_to      id x y                                     */
/* tclmcairo rel_move_to  id dx dy                                   */
/* tclmcairo rel_line_to  id dx dy                                   */
/* tclmcairo curve_to     id x1 y1 x2 y2 x3 y3                      */
/* tclmcairo rel_curve_to id dx1 dy1 dx2 dy2 dx3 dy3                */
/* tclmcairo close_path   id                                         */
/* tclmcairo new_path     id                                         */
/* tclmcairo new_sub_path id                                         */
/*                                                                    */
/* tclmcairo stroke          id  (consumes path)                     */
/* tclmcairo fill            id  (consumes path)                     */
/* tclmcairo fill_preserve   id  (fill, keep path for stroke)        */
/* tclmcairo stroke_preserve id  (stroke, keep path)                 */
/*                                                                    */
/* tclmcairo set_line_width   id n                                   */
/* tclmcairo set_line_cap     id butt|round|square                   */
/* tclmcairo set_line_join    id miter|round|bevel                   */
/* tclmcairo set_fill_rule    id winding|evenodd                     */
/* tclmcairo set_source_rgba  id r g b a                             */
/* tclmcairo set_source_rgb   id r g b                               */
/* ================================================================== */

/* ---- path commands ---- */
static int CairoMoveToCmd(ClientData cd, Tcl_Interp *i,
    int objc, Tcl_Obj *const objv[])
{
    (void)cd;
    if (objc != 5) { Tcl_WrongNumArgs(i,2,objv,"id x y"); return TCL_ERROR; }
    int id; GET_INT(i,objv[2],id);
    CairoCtx *c = ctx_find(id);
    if (!c) { Tcl_SetResult(i,"invalid id",TCL_STATIC); return TCL_ERROR; }
    double x,y; GET_DOUBLE(i,objv[3],x); GET_DOUBLE(i,objv[4],y);
    cairo_move_to(c->cr,x,y); return TCL_OK;
}
static int CairoLineToCmd(ClientData cd, Tcl_Interp *i,
    int objc, Tcl_Obj *const objv[])
{
    (void)cd;
    if (objc != 5) { Tcl_WrongNumArgs(i,2,objv,"id x y"); return TCL_ERROR; }
    int id; GET_INT(i,objv[2],id);
    CairoCtx *c = ctx_find(id);
    if (!c) { Tcl_SetResult(i,"invalid id",TCL_STATIC); return TCL_ERROR; }
    double x,y; GET_DOUBLE(i,objv[3],x); GET_DOUBLE(i,objv[4],y);
    cairo_line_to(c->cr,x,y); return TCL_OK;
}
static int CairoRelMoveToCmd(ClientData cd, Tcl_Interp *i,
    int objc, Tcl_Obj *const objv[])
{
    (void)cd;
    if (objc != 5) { Tcl_WrongNumArgs(i,2,objv,"id dx dy"); return TCL_ERROR; }
    int id; GET_INT(i,objv[2],id);
    CairoCtx *c = ctx_find(id);
    if (!c) { Tcl_SetResult(i,"invalid id",TCL_STATIC); return TCL_ERROR; }
    double dx,dy; GET_DOUBLE(i,objv[3],dx); GET_DOUBLE(i,objv[4],dy);
    cairo_rel_move_to(c->cr,dx,dy); return TCL_OK;
}
static int CairoRelLineToCmd(ClientData cd, Tcl_Interp *i,
    int objc, Tcl_Obj *const objv[])
{
    (void)cd;
    if (objc != 5) { Tcl_WrongNumArgs(i,2,objv,"id dx dy"); return TCL_ERROR; }
    int id; GET_INT(i,objv[2],id);
    CairoCtx *c = ctx_find(id);
    if (!c) { Tcl_SetResult(i,"invalid id",TCL_STATIC); return TCL_ERROR; }
    double dx,dy; GET_DOUBLE(i,objv[3],dx); GET_DOUBLE(i,objv[4],dy);
    cairo_rel_line_to(c->cr,dx,dy); return TCL_OK;
}
static int CairoCurveToCmd(ClientData cd, Tcl_Interp *i,
    int objc, Tcl_Obj *const objv[])
{
    (void)cd;
    if (objc != 9) { Tcl_WrongNumArgs(i,2,objv,"id x1 y1 x2 y2 x3 y3"); return TCL_ERROR; }
    int id; GET_INT(i,objv[2],id);
    CairoCtx *c = ctx_find(id);
    if (!c) { Tcl_SetResult(i,"invalid id",TCL_STATIC); return TCL_ERROR; }
    double x1,y1,x2,y2,x3,y3;
    GET_DOUBLE(i,objv[3],x1); GET_DOUBLE(i,objv[4],y1);
    GET_DOUBLE(i,objv[5],x2); GET_DOUBLE(i,objv[6],y2);
    GET_DOUBLE(i,objv[7],x3); GET_DOUBLE(i,objv[8],y3);
    cairo_curve_to(c->cr,x1,y1,x2,y2,x3,y3); return TCL_OK;
}
static int CairoRelCurveToCmd(ClientData cd, Tcl_Interp *i,
    int objc, Tcl_Obj *const objv[])
{
    (void)cd;
    if (objc < 9) { Tcl_WrongNumArgs(i,2,objv,"id dx1 dy1 dx2 dy2 dx3 dy3"); return TCL_ERROR; }
    int id; GET_INT(i,objv[2],id);
    CairoCtx *c = ctx_find(id);
    if (!c) { Tcl_SetResult(i,"invalid id",TCL_STATIC); return TCL_ERROR; }
    double x1,y1,x2,y2,x3,y3;
    GET_DOUBLE(i,objv[3],x1); GET_DOUBLE(i,objv[4],y1);
    GET_DOUBLE(i,objv[5],x2); GET_DOUBLE(i,objv[6],y2);
    GET_DOUBLE(i,objv[7],x3); GET_DOUBLE(i,objv[8],y3);
    cairo_rel_curve_to(c->cr,x1,y1,x2,y2,x3,y3); return TCL_OK;
}
static int CairoClosePathCmd(ClientData cd, Tcl_Interp *i,
    int objc, Tcl_Obj *const objv[])
{
    (void)cd;
    if (objc < 3) { Tcl_WrongNumArgs(i,2,objv,"id"); return TCL_ERROR; }
    int id; GET_INT(i,objv[2],id);
    CairoCtx *c = ctx_find(id);
    if (!c) { Tcl_SetResult(i,"invalid id",TCL_STATIC); return TCL_ERROR; }
    cairo_close_path(c->cr); return TCL_OK;
}
static int CairoNewPathCmd(ClientData cd, Tcl_Interp *i,
    int objc, Tcl_Obj *const objv[])
{
    (void)cd;
    if (objc < 3) { Tcl_WrongNumArgs(i,2,objv,"id"); return TCL_ERROR; }
    int id; GET_INT(i,objv[2],id);
    CairoCtx *c = ctx_find(id);
    if (!c) { Tcl_SetResult(i,"invalid id",TCL_STATIC); return TCL_ERROR; }
    cairo_new_path(c->cr); return TCL_OK;
}
static int CairoNewSubPathCmd(ClientData cd, Tcl_Interp *i,
    int objc, Tcl_Obj *const objv[])
{
    (void)cd;
    if (objc < 3) { Tcl_WrongNumArgs(i,2,objv,"id"); return TCL_ERROR; }
    int id; GET_INT(i,objv[2],id);
    CairoCtx *c = ctx_find(id);
    if (!c) { Tcl_SetResult(i,"invalid id",TCL_STATIC); return TCL_ERROR; }
    cairo_new_sub_path(c->cr); return TCL_OK;
}

/* ---- draw commands ---- */
static int CairoStrokeCmd(ClientData cd, Tcl_Interp *i,
    int objc, Tcl_Obj *const objv[])
{
    (void)cd;
    if (objc < 3) { Tcl_WrongNumArgs(i,2,objv,"id"); return TCL_ERROR; }
    int id; GET_INT(i,objv[2],id);
    CairoCtx *c = ctx_find(id);
    if (!c) { Tcl_SetResult(i,"invalid id",TCL_STATIC); return TCL_ERROR; }
    cairo_stroke(c->cr); return TCL_OK;
}
static int CairoFillCmd(ClientData cd, Tcl_Interp *i,
    int objc, Tcl_Obj *const objv[])
{
    (void)cd;
    if (objc < 3) { Tcl_WrongNumArgs(i,2,objv,"id"); return TCL_ERROR; }
    int id; GET_INT(i,objv[2],id);
    CairoCtx *c = ctx_find(id);
    if (!c) { Tcl_SetResult(i,"invalid id",TCL_STATIC); return TCL_ERROR; }
    cairo_fill(c->cr); return TCL_OK;
}
static int CairoFillPreserveCmd(ClientData cd, Tcl_Interp *i,
    int objc, Tcl_Obj *const objv[])
{
    (void)cd;
    if (objc < 3) { Tcl_WrongNumArgs(i,2,objv,"id"); return TCL_ERROR; }
    int id; GET_INT(i,objv[2],id);
    CairoCtx *c = ctx_find(id);
    if (!c) { Tcl_SetResult(i,"invalid id",TCL_STATIC); return TCL_ERROR; }
    cairo_fill_preserve(c->cr); return TCL_OK;
}
static int CairoStrokePreserveCmd(ClientData cd, Tcl_Interp *i,
    int objc, Tcl_Obj *const objv[])
{
    (void)cd;
    if (objc < 3) { Tcl_WrongNumArgs(i,2,objv,"id"); return TCL_ERROR; }
    int id; GET_INT(i,objv[2],id);
    CairoCtx *c = ctx_find(id);
    if (!c) { Tcl_SetResult(i,"invalid id",TCL_STATIC); return TCL_ERROR; }
    cairo_stroke_preserve(c->cr); return TCL_OK;
}

/* ---- style setters ---- */
static int CairoSetLineWidthCmd(ClientData cd, Tcl_Interp *i,
    int objc, Tcl_Obj *const objv[])
{
    (void)cd;
    if (objc < 4) { Tcl_WrongNumArgs(i,2,objv,"id width"); return TCL_ERROR; }
    int id; GET_INT(i,objv[2],id);
    CairoCtx *c = ctx_find(id);
    if (!c) { Tcl_SetResult(i,"invalid id",TCL_STATIC); return TCL_ERROR; }
    double w; GET_DOUBLE(i,objv[3],w);
    cairo_set_line_width(c->cr,w); return TCL_OK;
}
static int CairoSetLineCapCmd(ClientData cd, Tcl_Interp *i,
    int objc, Tcl_Obj *const objv[])
{
    (void)cd;
    if (objc < 4) { Tcl_WrongNumArgs(i,2,objv,"id butt|round|square"); return TCL_ERROR; }
    int id; GET_INT(i,objv[2],id);
    CairoCtx *c = ctx_find(id);
    if (!c) { Tcl_SetResult(i,"invalid id",TCL_STATIC); return TCL_ERROR; }
    const char *v = Tcl_GetString(objv[3]);
    cairo_line_cap_t cap;
    if      (!strcmp(v,"butt"))   cap = CAIRO_LINE_CAP_BUTT;
    else if (!strcmp(v,"round"))  cap = CAIRO_LINE_CAP_ROUND;
    else if (!strcmp(v,"square")) cap = CAIRO_LINE_CAP_SQUARE;
    else {
        Tcl_SetObjResult(i, Tcl_ObjPrintf("invalid linecap: %s (butt|round|square)", v));
        return TCL_ERROR;
    }
    cairo_set_line_cap(c->cr,cap); return TCL_OK;
}
static int CairoSetLineJoinCmd(ClientData cd, Tcl_Interp *i,
    int objc, Tcl_Obj *const objv[])
{
    (void)cd;
    if (objc < 4) { Tcl_WrongNumArgs(i,2,objv,"id miter|round|bevel"); return TCL_ERROR; }
    int id; GET_INT(i,objv[2],id);
    CairoCtx *c = ctx_find(id);
    if (!c) { Tcl_SetResult(i,"invalid id",TCL_STATIC); return TCL_ERROR; }
    const char *v = Tcl_GetString(objv[3]);
    cairo_line_join_t join;
    if      (!strcmp(v,"miter")) join = CAIRO_LINE_JOIN_MITER;
    else if (!strcmp(v,"round")) join = CAIRO_LINE_JOIN_ROUND;
    else if (!strcmp(v,"bevel")) join = CAIRO_LINE_JOIN_BEVEL;
    else {
        Tcl_SetObjResult(i, Tcl_ObjPrintf("invalid linejoin: %s (miter|round|bevel)", v));
        return TCL_ERROR;
    }
    cairo_set_line_join(c->cr,join); return TCL_OK;
}
static int CairoSetFillRuleCmd(ClientData cd, Tcl_Interp *i,
    int objc, Tcl_Obj *const objv[])
{
    (void)cd;
    if (objc < 4) { Tcl_WrongNumArgs(i,2,objv,"id winding|evenodd"); return TCL_ERROR; }
    int id; GET_INT(i,objv[2],id);
    CairoCtx *c = ctx_find(id);
    if (!c) { Tcl_SetResult(i,"invalid id",TCL_STATIC); return TCL_ERROR; }
    const char *v = Tcl_GetString(objv[3]);
    if      (!strcmp(v,"winding")) cairo_set_fill_rule(c->cr,CAIRO_FILL_RULE_WINDING);
    else if (!strcmp(v,"evenodd")) cairo_set_fill_rule(c->cr,CAIRO_FILL_RULE_EVEN_ODD);
    else {
        Tcl_SetObjResult(i, Tcl_ObjPrintf("invalid fillrule: %s (winding|evenodd)", v));
        return TCL_ERROR;
    }
    return TCL_OK;
}
static int CairoSetSourceRGBACmd(ClientData cd, Tcl_Interp *i,
    int objc, Tcl_Obj *const objv[])
{
    (void)cd;
    if (objc < 7) { Tcl_WrongNumArgs(i,2,objv,"id r g b a"); return TCL_ERROR; }
    int id; GET_INT(i,objv[2],id);
    CairoCtx *c = ctx_find(id);
    if (!c) { Tcl_SetResult(i,"invalid id",TCL_STATIC); return TCL_ERROR; }
    double r,g,b,a;
    GET_DOUBLE(i,objv[3],r); GET_DOUBLE(i,objv[4],g);
    GET_DOUBLE(i,objv[5],b); GET_DOUBLE(i,objv[6],a);
    cairo_set_source_rgba(c->cr,r,g,b,a); return TCL_OK;
}
static int CairoSetSourceRGBCmd(ClientData cd, Tcl_Interp *i,
    int objc, Tcl_Obj *const objv[])
{
    (void)cd;
    if (objc < 6) { Tcl_WrongNumArgs(i,2,objv,"id r g b"); return TCL_ERROR; }
    int id; GET_INT(i,objv[2],id);
    CairoCtx *c = ctx_find(id);
    if (!c) { Tcl_SetResult(i,"invalid id",TCL_STATIC); return TCL_ERROR; }
    double r,g,b;
    GET_DOUBLE(i,objv[3],r); GET_DOUBLE(i,objv[4],g); GET_DOUBLE(i,objv[5],b);
    cairo_set_source_rgb(c->cr,r,g,b); return TCL_OK;
}

static int TkmCairoCmd(ClientData cd, Tcl_Interp *interp,
    int objc, Tcl_Obj *const objv[])
{
    if (objc < 2) {
        Tcl_WrongNumArgs(interp, 1, objv,
            "create|destroy|clear|save|size|todata|newpage|finish|"
            "push|pop|clip_rect|clip_path|clip_reset|"
            "image|rect|line|circle|ellipse|arc|poly|path|text|text_path|"
            "font_measure|transform|gradient_linear|gradient_radial ...");
        return TCL_ERROR;
    }
/* ================================================================== */
/* ================================================================== */
    const char *sub = Tcl_GetString(objv[1]);

    if      (!strcmp(sub,"create"))           return CairoCreateCmd(cd,interp,objc,objv);
    else if (!strcmp(sub,"destroy"))          return CairoDestroyCmd(cd,interp,objc,objv);
    else if (!strcmp(sub,"clear"))            return CairoClearCmd(cd,interp,objc,objv);
    else if (!strcmp(sub,"size"))             return CairoSizeCmd(cd,interp,objc,objv);
    else if (!strcmp(sub,"todata"))           return CairoToDataCmd(cd,interp,objc,objv);
    else if (!strcmp(sub,"topng"))            return CairoToPngCmd(cd,interp,objc,objv);
    else if (!strcmp(sub,"image_data"))       return CairoImageDataCmd(cd,interp,objc,objv);
    else if (!strcmp(sub,"save"))             return CairoSaveCmd(cd,interp,objc,objv);
    else if (!strcmp(sub,"newpage"))          return CairoNewPageCmd(cd,interp,objc,objv);
    else if (!strcmp(sub,"finish"))           return CairoFinishCmd(cd,interp,objc,objv);
    else if (!strcmp(sub,"push"))             return CairoPushCmd(cd,interp,objc,objv);
    else if (!strcmp(sub,"pop"))              return CairoPopCmd(cd,interp,objc,objv);
    else if (!strcmp(sub,"clip_rect"))        return CairoClipRectCmd(cd,interp,objc,objv);
    else if (!strcmp(sub,"clip_path"))        return CairoClipPathCmd(cd,interp,objc,objv);
    else if (!strcmp(sub,"clip_reset"))       return CairoClipResetCmd(cd,interp,objc,objv);
    else if (!strcmp(sub,"image"))            return CairoImageCmd(cd,interp,objc,objv);
    else if (!strcmp(sub,"blit"))             return CairoBlitCmd(cd,interp,objc,objv);
    else if (!strcmp(sub,"rect"))             return CairoRectCmd(cd,interp,objc,objv);
    else if (!strcmp(sub,"line"))             return CairoLineCmd(cd,interp,objc,objv);
    else if (!strcmp(sub,"circle"))           return CairoCircleCmd(cd,interp,objc,objv);
    else if (!strcmp(sub,"ellipse"))          return CairoEllipseCmd(cd,interp,objc,objv);
    else if (!strcmp(sub,"arc"))              return CairoArcCmd(cd,interp,objc,objv);
    else if (!strcmp(sub,"poly"))             return CairoPolyCmd(cd,interp,objc,objv);
    else if (!strcmp(sub,"path"))             return CairoPathCmd(cd,interp,objc,objv);
    else if (!strcmp(sub,"text"))             return CairoTextCmd(cd,interp,objc,objv);
    else if (!strcmp(sub,"text_path"))        return CairoTextPathCmd(cd,interp,objc,objv);
    else if (!strcmp(sub,"font_measure"))     return CairoFontMeasureCmd(cd,interp,objc,objv);
    else if (!strcmp(sub,"transform"))        return CairoTransformCmd(cd,interp,objc,objv);
    else if (!strcmp(sub,"operator"))         return CairoOperatorCmd(cd,interp,objc,objv);
    else if (!strcmp(sub,"user_to_device"))   return CairoUserToDeviceCmd(cd,interp,objc,objv);
    else if (!strcmp(sub,"device_to_user"))   return CairoDeviceToUserCmd(cd,interp,objc,objv);
    else if (!strcmp(sub,"arc_negative"))     return CairoArcNegativeCmd(cd,interp,objc,objv);
    else if (!strcmp(sub,"recording_bbox"))   return CairoRecordingBboxCmd(cd,interp,objc,objv);
    else if (!strcmp(sub,"gradient_linear"))  return CairoGradientCmd(cd,interp,objc,objv,0);
    else if (!strcmp(sub,"gradient_radial"))  return CairoGradientCmd(cd,interp,objc,objv,1);
    else if (!strcmp(sub,"gradient_extend"))  return CairoGradientExtendCmd(cd,interp,objc,objv);
    else if (!strcmp(sub,"gradient_filter"))  return CairoGradientFilterCmd(cd,interp,objc,objv);
    else if (!strcmp(sub,"paint"))            return CairoPaintCmd(cd,interp,objc,objv);
    else if (!strcmp(sub,"set_source"))       return CairoSetSourceCmd(cd,interp,objc,objv);
    else if (!strcmp(sub,"font_options"))     return CairoFontOptionsCmd(cd,interp,objc,objv);
    else if (!strcmp(sub,"path_get"))         return CairoPathGetCmd(cd,interp,objc,objv);
    else if (!strcmp(sub,"surface_copy"))     return CairoSurfaceCopyCmd(cd,interp,objc,objv);
    /* Low-level path commands (Cairo samples API) */
    else if (!strcmp(sub,"move_to"))          return CairoMoveToCmd(cd,interp,objc,objv);
    else if (!strcmp(sub,"line_to"))          return CairoLineToCmd(cd,interp,objc,objv);
    else if (!strcmp(sub,"rel_move_to"))      return CairoRelMoveToCmd(cd,interp,objc,objv);
    else if (!strcmp(sub,"rel_line_to"))      return CairoRelLineToCmd(cd,interp,objc,objv);
    else if (!strcmp(sub,"curve_to"))         return CairoCurveToCmd(cd,interp,objc,objv);
    else if (!strcmp(sub,"rel_curve_to"))     return CairoRelCurveToCmd(cd,interp,objc,objv);
    else if (!strcmp(sub,"close_path"))       return CairoClosePathCmd(cd,interp,objc,objv);
    else if (!strcmp(sub,"new_path"))         return CairoNewPathCmd(cd,interp,objc,objv);
    else if (!strcmp(sub,"new_sub_path"))     return CairoNewSubPathCmd(cd,interp,objc,objv);
    else if (!strcmp(sub,"stroke"))           return CairoStrokeCmd(cd,interp,objc,objv);
    else if (!strcmp(sub,"fill"))             return CairoFillCmd(cd,interp,objc,objv);
    else if (!strcmp(sub,"fill_preserve"))    return CairoFillPreserveCmd(cd,interp,objc,objv);
    else if (!strcmp(sub,"stroke_preserve"))  return CairoStrokePreserveCmd(cd,interp,objc,objv);
    else if (!strcmp(sub,"set_line_width"))   return CairoSetLineWidthCmd(cd,interp,objc,objv);
    else if (!strcmp(sub,"set_line_cap"))     return CairoSetLineCapCmd(cd,interp,objc,objv);
    else if (!strcmp(sub,"set_line_join"))    return CairoSetLineJoinCmd(cd,interp,objc,objv);
    else if (!strcmp(sub,"set_fill_rule"))    return CairoSetFillRuleCmd(cd,interp,objc,objv);
    else if (!strcmp(sub,"set_source_rgba"))  return CairoSetSourceRGBACmd(cd,interp,objc,objv);
    else if (!strcmp(sub,"set_source_rgb"))   return CairoSetSourceRGBCmd(cd,interp,objc,objv);
    else {
        Tcl_SetObjResult(interp,
            Tcl_ObjPrintf("unknown subcommand \"%s\"", sub));
        return TCL_ERROR;
    }
}

/* ================================================================== */
/* Package init                                                        */
/* ================================================================== */

/* Cleanup all contexts on interpreter deletion (Tcl_CallWhenDeleted) */
static void TclmcairoInterpCleanup(ClientData cd, Tcl_Interp *interp)
{
    (void)cd; (void)interp;
    for (int i = 0; i < MAX_CTX; i++) {
        if (!g_ctx[i]) continue;
        CairoCtx *c = g_ctx[i];
        for (int j = 0; j < c->ngrads; j++)
            cairo_pattern_destroy(c->grads[j].pattern);
        if (c->cr) cairo_destroy(c->cr);
        if (!c->finished &&
            (c->mode == MODE_PDF || c->mode == MODE_SVG ||
             c->mode == MODE_PS  || c->mode == MODE_EPS)) {
            if (c->surface) cairo_surface_finish(c->surface);
        }
        if (c->rec && c->rec != c->surface) cairo_surface_destroy(c->rec);
        if (c->surface) cairo_surface_destroy(c->surface);
        free(c);
        g_ctx[i] = NULL;
    }
}

int Tclmcairo_Init(Tcl_Interp *interp)
{
#ifdef USE_TCL_STUBS
#if TCL_MAJOR_VERSION >= 9
    if (Tcl_InitStubs(interp, "9.0", 0) == NULL) return TCL_ERROR;
#else
    if (Tcl_InitStubs(interp, "8.6", 0) == NULL) return TCL_ERROR;
#endif
#endif
    Tcl_CreateObjCommand(interp, "tclmcairo", TkmCairoCmd, NULL, NULL);
    /* Register cleanup callback — frees all contexts on interp deletion */
    Tcl_CallWhenDeleted(interp, TclmcairoInterpCleanup, NULL);
    Tcl_PkgProvide(interp, "tclmcairo", "0.3");
    return TCL_OK;
}