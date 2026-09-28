#pragma once
/*
 * Proportional UI scaling helpers.
 *
 * The CalPoly / Brookesia UI in this project was authored on a 1024x600 (7")
 * panel using hard-coded pixel coordinates. The 5" CrowPanel Advanced uses an
 * 800x480 panel, so every absolute coordinate and font has to shrink to keep
 * the layout looking the same proportionally.
 *
 *   horizontal factor = 800 / 1024 = 0.781
 *   vertical   factor = 480 / 600  = 0.800
 *
 * Use UI_SX() for X positions / widths and UI_SY() for Y positions / heights.
 * UI_S() is a generic (vertical) scale for radii, padding, shadows, etc.
 * ui_font_scaled(px) returns the nearest compiled Montserrat font for a design
 * size scaled by the vertical factor.
 */

#include "lvgl.h"

#define UI_DESIGN_W 1024
#define UI_DESIGN_H 600
#define UI_SCREEN_W 800
#define UI_SCREEN_H 480

#define UI_SX(v) ((lv_coord_t)(((int)(v) * UI_SCREEN_W) / UI_DESIGN_W))
#define UI_SY(v) ((lv_coord_t)(((int)(v) * UI_SCREEN_H) / UI_DESIGN_H))
#define UI_S(v)  UI_SY(v)

static inline __attribute__((unused)) const lv_font_t *ui_font_scaled(int design_px)
{
    int t = (design_px * UI_SCREEN_H) / UI_DESIGN_H;
    static const int sizes[] = {8, 10, 12, 14, 16, 18, 20, 22, 24, 26, 28,
                                30, 32, 34, 36, 38, 40, 42, 44, 46, 48};
    int best = sizes[0];
    int best_d = (t > sizes[0]) ? (t - sizes[0]) : (sizes[0] - t);
    for (unsigned i = 1; i < sizeof(sizes) / sizeof(sizes[0]); ++i) {
        int d = (t > sizes[i]) ? (t - sizes[i]) : (sizes[i] - t);
        if (d < best_d) {
            best_d = d;
            best = sizes[i];
        }
    }
    switch (best) {
        case 8:  return &lv_font_montserrat_8;
        case 10: return &lv_font_montserrat_10;
        case 12: return &lv_font_montserrat_12;
        case 14: return &lv_font_montserrat_14;
        case 16: return &lv_font_montserrat_16;
        case 18: return &lv_font_montserrat_18;
        case 20: return &lv_font_montserrat_20;
        case 22: return &lv_font_montserrat_22;
        case 24: return &lv_font_montserrat_24;
        case 26: return &lv_font_montserrat_26;
        case 28: return &lv_font_montserrat_28;
        case 30: return &lv_font_montserrat_30;
        case 32: return &lv_font_montserrat_32;
        case 34: return &lv_font_montserrat_34;
        case 36: return &lv_font_montserrat_36;
        case 38: return &lv_font_montserrat_38;
        case 40: return &lv_font_montserrat_40;
        case 42: return &lv_font_montserrat_42;
        case 44: return &lv_font_montserrat_44;
        case 46: return &lv_font_montserrat_46;
        case 48: return &lv_font_montserrat_48;
        default: return &lv_font_montserrat_16;
    }
}
