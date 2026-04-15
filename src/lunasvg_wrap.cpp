/* lunasvg_wrap.cpp — C++ Wrapper für lunasvg → tclmcairo
 *
 * Bindet lunasvg (C++) in libtclmcairo.c (C) ein.
 * Neue Befehle:
 *   tclmcairo svg_file_luna id filename x y ?-width w? ?-height h? ?-scale s? ?-bg color?
 *   tclmcairo svg_data_luna id svgstring x y ?-width w? ?-height h? ?-scale s? ?-bg color?
 *   tclmcairo svg_size_luna id filename -> {width height}
 *
 * ARGB32 Premultiplied (lunasvg) → cairo_image_surface_create_for_data
 *
 * Part of tclmcairo — https://github.com/gregnix/tclmcairo
 * License: BSD 2-Clause
 */

#include <lunasvg.h>
#include <cairo/cairo.h>
#include <cstring>
#include <cstdlib>
#include <string>

#ifdef __cplusplus
extern "C" {
#endif

#include <tcl.h>

/* ------------------------------------------------------------------ */
/* Shared render helper: lunasvg Bitmap → Cairo Surface → paint       */
/* ------------------------------------------------------------------ */
static int _lunasvg_paint(Tcl_Interp* interp, cairo_t* cr,
    lunasvg::Document* doc,
    double dx, double dy,
    int req_w, int req_h, double scale,
    uint32_t bgcolor)
{
    /* Determine render dimensions */
    int rw = req_w, rh = req_h;
    if (scale > 0) {
        rw = (int)(doc->width()  * scale + 0.5);
        rh = (int)(doc->height() * scale + 0.5);
    } else if (rw <= 0 && rh <= 0) {
        rw = (int)(doc->width()  + 0.5);
        rh = (int)(doc->height() + 0.5);
    } else if (rw <= 0) {
        double ratio = doc->width() / doc->height();
        rw = (int)(rh * ratio + 0.5);
    } else if (rh <= 0) {
        double ratio = doc->height() / doc->width();
        rh = (int)(rw * ratio + 0.5);
    }
    if (rw < 1) rw = 1;
    if (rh < 1) rh = 1;

    /* Render SVG → ARGB32 Premultiplied Bitmap */
    lunasvg::Bitmap bmp = doc->renderToBitmap(rw, rh, bgcolor);
    if (bmp.isNull()) {
        Tcl_SetResult(interp, (char*)"lunasvg: renderToBitmap failed", TCL_STATIC);
        return TCL_ERROR;
    }

    /* lunasvg gives ARGB32 premultiplied — Cairo ARGB32 is the same format */
    cairo_surface_t* surf = cairo_image_surface_create_for_data(
        bmp.data(),
        CAIRO_FORMAT_ARGB32,
        bmp.width(), bmp.height(),
        bmp.stride());

    if (cairo_surface_status(surf) != CAIRO_STATUS_SUCCESS) {
        cairo_surface_destroy(surf);
        Tcl_SetResult(interp, (char*)"lunasvg: cairo surface create failed", TCL_STATIC);
        return TCL_ERROR;
    }

    cairo_save(cr);
    cairo_set_source_surface(cr, surf, dx, dy);
    cairo_rectangle(cr, dx, dy, rw, rh);
    cairo_fill(cr);
    cairo_restore(cr);

    cairo_surface_finish(surf);
    cairo_surface_destroy(surf);
    return TCL_OK;
}

/* ------------------------------------------------------------------ */
/* Parse common options: -width -height -scale -bg                    */
/* ------------------------------------------------------------------ */
static void _parse_opts(int objc, Tcl_Obj* const objv[],
    double& dx, double& dy,
    int& req_w, int& req_h, double& scale, uint32_t& bgcolor)
{
    for (int i = 0; i+1 < objc; i += 2) {
        const char* opt = Tcl_GetString(objv[i]);
        if (!strcmp(opt, "-width")) {
            int v; Tcl_GetIntFromObj(NULL, objv[i+1], &v); req_w = v;
        } else if (!strcmp(opt, "-height")) {
            int v; Tcl_GetIntFromObj(NULL, objv[i+1], &v); req_h = v;
        } else if (!strcmp(opt, "-scale")) {
            double v; Tcl_GetDoubleFromObj(NULL, objv[i+1], &v); scale = v;
        } else if (!strcmp(opt, "-bg")) {
            /* -bg 0xrrggbbaa or color string ignored for now */
            long v; Tcl_GetLongFromObj(NULL, objv[i+1], &v);
            bgcolor = (uint32_t)v;
        }
    }
}

/* ------------------------------------------------------------------ */
/* Public C functions — called from libtclmcairo.c                    */
/* ------------------------------------------------------------------ */

int LunaSvgFileCmd(cairo_t* cr, Tcl_Interp* interp,
    int objc, Tcl_Obj* const objv[])
{
    /* objv: filename x y ?opts? (no leading dummy) */
    if (objc < 3) {
        Tcl_WrongNumArgs(interp, 0, objv,
            "filename x y ?-width w? ?-height h? ?-scale s?");
        return TCL_ERROR;
    }

    const char* fname = Tcl_GetString(objv[0]);
    double dx = 0, dy = 0;
    Tcl_GetDoubleFromObj(interp, objv[1], &dx);
    Tcl_GetDoubleFromObj(interp, objv[2], &dy);

    int req_w = -1, req_h = -1;
    double scale = -1;
    uint32_t bgcolor = 0x00000000;
    _parse_opts(objc - 3, objv + 3, dx, dy, req_w, req_h, scale, bgcolor);

    auto doc = lunasvg::Document::loadFromFile(std::string(fname));
    if (!doc) {
        Tcl_SetResult(interp, (char*)"lunasvg: cannot load SVG file", TCL_STATIC);
        return TCL_ERROR;
    }

    return _lunasvg_paint(interp, cr, doc.get(),
        dx, dy, req_w, req_h, scale, bgcolor);
}

int LunaSvgDataCmd(cairo_t* cr, Tcl_Interp* interp,
    int objc, Tcl_Obj* const objv[])
{
    /* objv: svgdata x y ?opts? (no leading dummy) */
    if (objc < 3) {
        Tcl_WrongNumArgs(interp, 0, objv,
            "svgdata x y ?-width w? ?-height h? ?-scale s?");
        return TCL_ERROR;
    }

    int len = 0;
    const char* data = Tcl_GetStringFromObj(objv[0], &len);
    double dx = 0, dy = 0;
    Tcl_GetDoubleFromObj(interp, objv[1], &dx);
    Tcl_GetDoubleFromObj(interp, objv[2], &dy);

    int req_w = -1, req_h = -1;
    double scale = -1;
    uint32_t bgcolor = 0x00000000;
    _parse_opts(objc - 3, objv + 3, dx, dy, req_w, req_h, scale, bgcolor);

    auto doc = lunasvg::Document::loadFromData(data, (size_t)len);
    if (!doc) {
        Tcl_SetResult(interp, (char*)"lunasvg: cannot parse SVG data", TCL_STATIC);
        return TCL_ERROR;
    }

    return _lunasvg_paint(interp, cr, doc.get(),
        dx, dy, req_w, req_h, scale, bgcolor);
}

int LunaSvgSizeCmd(Tcl_Interp* interp,
    int objc, Tcl_Obj* const objv[])
{
    /* objv: filename (no leading dummy) */
    if (objc < 1) {
        Tcl_WrongNumArgs(interp, 0, objv, "filename");
        return TCL_ERROR;
    }
    const char* fname = Tcl_GetString(objv[0]);
    auto doc = lunasvg::Document::loadFromFile(std::string(fname));
    if (!doc) {
        Tcl_SetResult(interp, (char*)"lunasvg: cannot load SVG file", TCL_STATIC);
        return TCL_ERROR;
    }
    Tcl_Obj* lst = Tcl_NewListObj(0, NULL);
    Tcl_ListObjAppendElement(interp, lst,
        Tcl_NewDoubleObj(doc->width()));
    Tcl_ListObjAppendElement(interp, lst,
        Tcl_NewDoubleObj(doc->height()));
    Tcl_SetObjResult(interp, lst);
    return TCL_OK;
}

#ifdef __cplusplus
}
#endif
