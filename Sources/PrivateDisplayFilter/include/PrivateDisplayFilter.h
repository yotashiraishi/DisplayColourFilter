#ifndef PRIVATE_DISPLAY_FILTER_H
#define PRIVATE_DISPLAY_FILTER_H

#include <stdbool.h>
#include <stdint.h>

// macOS の非公開 API(SkyLight / MediaAccessibility)を dlsym で読み込んで使う薄いラッパー。
// 行列はすべて 3x3・行優先の float[9](出力RGB = 行列 × 入力RGB)。

/// 必要な非公開 API をすべて読み込めたか(初回呼び出し時に読み込む)
bool PDFIsAvailable(void);

/// システムのカラーフィルタと同じ行列を作る。
/// type: 1=グレイスケール, 2=赤/緑(1型色覚), 4=緑/赤(2型色覚), 8=青/黄(3型色覚), 16=カラーティント
/// intensity: 強さ(0.25〜1.0)、hue: 色合い(0〜1、カラーティントのみ使用)
bool PDFMakeFilterMatrix(int type, double intensity, double hue, float outMatrix[9]);

/// 指定ディスプレイ(CGDirectDisplayID)にだけ行列を適用する
bool PDFApplyMatrixToDisplay(uint32_t displayID, const float matrix[9]);

/// 全ディスプレイをシステム設定どおりの状態に戻す
/// (システムのカラーフィルタが ON ならそのフィルター、OFF ならフィルター無し)
bool PDFRestoreSystemState(void);

#endif
