#include "PrivateDisplayFilter.h"

#include <CoreFoundation/CoreFoundation.h>
#include <dlfcn.h>
#include <pthread.h>

// MADisplayFilterGetMatrix の戻り値(double の 3x3、行優先)
typedef struct { double m[9]; } PDFFilterMatrix;

static int32_t (*SLSSetAccessibilityAdjustments_)(CFDictionaryRef);
static CFStringRef matrixKey;
static CFStringRef targetDisplayKey;

static CFTypeRef (*MADisplayFilterCreateGrayscale_)(double intensity);
static CFTypeRef (*MADisplayFilterCreateRedColorCorrection_)(double intensity);
static CFTypeRef (*MADisplayFilterCreateGreenColorCorrection_)(double intensity);
static CFTypeRef (*MADisplayFilterCreateBlueColorCorrection_)(double intensity);
// 第2・第3引数は使われない(システムも値を渡していない)
static CFTypeRef (*MADisplayFilterCreateSingleColor_)(double hue, double unused1, double unused2, double intensity);
static PDFFilterMatrix (*MADisplayFilterGetMatrix_)(CFTypeRef filter);
static CFTypeRef (*MADisplayFilterCopySystemFilter_)(long, long, long);
static bool (*MADisplayFilterPrefGetCategoryEnabled_)(long category);

static bool loaded;
static pthread_once_t loadOnce = PTHREAD_ONCE_INIT;

static void load(void) {
    void *skyLight = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY);
    void *mediaAccessibility = dlopen("/System/Library/Frameworks/MediaAccessibility.framework/MediaAccessibility", RTLD_LAZY);
    if (!skyLight || !mediaAccessibility) return;

    SLSSetAccessibilityAdjustments_ = dlsym(skyLight, "SLSSetAccessibilityAdjustments");
    CFStringRef *matrixKeyPtr = dlsym(skyLight, "kSLSAccessibilityAdjustmentMatrix");
    CFStringRef *targetDisplayKeyPtr = dlsym(skyLight, "kSLSAccessibilityTargetDisplay");

    MADisplayFilterCreateGrayscale_ = dlsym(mediaAccessibility, "MADisplayFilterCreateGrayscale");
    MADisplayFilterCreateRedColorCorrection_ = dlsym(mediaAccessibility, "MADisplayFilterCreateRedColorCorrection");
    MADisplayFilterCreateGreenColorCorrection_ = dlsym(mediaAccessibility, "MADisplayFilterCreateGreenColorCorrection");
    MADisplayFilterCreateBlueColorCorrection_ = dlsym(mediaAccessibility, "MADisplayFilterCreateBlueColorCorrection");
    MADisplayFilterCreateSingleColor_ = dlsym(mediaAccessibility, "MADisplayFilterCreateSingleColor");
    MADisplayFilterGetMatrix_ = dlsym(mediaAccessibility, "MADisplayFilterGetMatrix");
    MADisplayFilterCopySystemFilter_ = dlsym(mediaAccessibility, "MADisplayFilterCopySystemFilter");
    MADisplayFilterPrefGetCategoryEnabled_ = dlsym(mediaAccessibility, "MADisplayFilterPrefGetCategoryEnabled");

    if (!SLSSetAccessibilityAdjustments_ || !matrixKeyPtr || !targetDisplayKeyPtr ||
        !MADisplayFilterCreateGrayscale_ || !MADisplayFilterCreateRedColorCorrection_ ||
        !MADisplayFilterCreateGreenColorCorrection_ || !MADisplayFilterCreateBlueColorCorrection_ ||
        !MADisplayFilterCreateSingleColor_ || !MADisplayFilterGetMatrix_ ||
        !MADisplayFilterCopySystemFilter_ || !MADisplayFilterPrefGetCategoryEnabled_) return;

    matrixKey = *matrixKeyPtr;
    targetDisplayKey = *targetDisplayKeyPtr;
    loaded = true;
}

bool PDFIsAvailable(void) {
    pthread_once(&loadOnce, load);
    return loaded;
}

static void copyMatrix(CFTypeRef filter, float outMatrix[9]) {
    PDFFilterMatrix m = MADisplayFilterGetMatrix_(filter);
    for (int i = 0; i < 9; i++) outMatrix[i] = (float)m.m[i];
}

bool PDFMakeFilterMatrix(int type, double intensity, double hue, float outMatrix[9]) {
    if (!PDFIsAvailable()) return false;

    CFTypeRef filter = NULL;
    switch (type) {
        case 1: filter = MADisplayFilterCreateGrayscale_(intensity); break;
        case 2: filter = MADisplayFilterCreateRedColorCorrection_(intensity); break;
        case 4: filter = MADisplayFilterCreateGreenColorCorrection_(intensity); break;
        case 8: filter = MADisplayFilterCreateBlueColorCorrection_(intensity); break;
        case 16: filter = MADisplayFilterCreateSingleColor_(hue, 1.0, 1.0, intensity); break;
    }
    if (!filter) return false;

    copyMatrix(filter, outMatrix);
    CFRelease(filter);
    return true;
}

// displayID が 0 のときは全ディスプレイに適用される(WindowServer 側の仕様)
static bool applyMatrix(uint32_t displayID, const float matrix[9]) {
    CFMutableDictionaryRef adjustments = CFDictionaryCreateMutable(NULL, 2, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);

    CFDataRef matrixData = CFDataCreate(NULL, (const UInt8 *)matrix, sizeof(float) * 9);
    CFDictionarySetValue(adjustments, matrixKey, matrixData);
    CFRelease(matrixData);

    if (displayID != 0) {
        int64_t value = displayID;
        CFNumberRef number = CFNumberCreate(NULL, kCFNumberSInt64Type, &value);
        CFDictionarySetValue(adjustments, targetDisplayKey, number);
        CFRelease(number);
    }

    int32_t error = SLSSetAccessibilityAdjustments_(adjustments);
    CFRelease(adjustments);
    return error == 0;
}

bool PDFApplyMatrixToDisplay(uint32_t displayID, const float matrix[9]) {
    // 0 を渡すと全ディスプレイに掛かってしまうので弾く
    if (!PDFIsAvailable() || displayID == 0) return false;
    return applyMatrix(displayID, matrix);
}

bool PDFRestoreSystemState(void) {
    if (!PDFIsAvailable()) return false;

    // universalaccessd がやっているのと同じ手順(カテゴリ 1 = カラーフィルタ)
    float matrix[9] = {1, 0, 0, 0, 1, 0, 0, 0, 1};
    if (MADisplayFilterPrefGetCategoryEnabled_(1)) {
        CFTypeRef filter = MADisplayFilterCopySystemFilter_(0, 1, 0);
        if (filter) {
            copyMatrix(filter, matrix);
            CFRelease(filter);
        }
    }
    return applyMatrix(0, matrix);
}
