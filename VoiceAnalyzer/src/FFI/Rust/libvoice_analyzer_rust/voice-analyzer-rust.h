#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

#define FORMANT_COUNT 2

typedef enum PitchEstimationAlgorithm {
  PitchEstimationAlgorithm_Irapt,
  PitchEstimationAlgorithm_Yin,
} PitchEstimationAlgorithm;

typedef struct AnalyzerState AnalyzerState;

typedef struct Pitch {
  float value;
  float confidence;
} Pitch;

typedef struct Formant {
  float frequency;
  float bandwidth;
} Formant;

typedef struct AnalyzerOutput {
  struct Pitch pitch;
  struct Formant formants[FORMANT_COUNT];
} AnalyzerOutput;

struct AnalyzerState *voice_analyzer_rust_analyzer_new(double sample_rate,
                                                       enum PitchEstimationAlgorithm pitch_estimation_algorithm);

struct AnalyzerOutput voice_analyzer_rust_analyzer_process(struct AnalyzerState *p_analyzer,
                                                           const float *p_samples,
                                                           uintptr_t samples_len);

void voice_analyzer_rust_analyzer_drop(struct AnalyzerState *p_analyzer);
