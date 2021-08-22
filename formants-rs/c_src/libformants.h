#ifndef _GUARD_LIBFORMANTS_H
#define _GUARD_LIBFORMANTS_H

#ifndef FORMANTS_NAMESPACE
#define FORMANTS_NAMESPACE formants_
#endif

#ifndef FORMANTS_FLOAT
#define FORMANTS_FLOAT double
#endif

#define CAT_PREFIX2(a, b) a ## b
#define CAT_PREFIX(a, b) CAT_PREFIX2(a, b)
#define NS(name) CAT_PREFIX(FORMANTS_NAMESPACE, name)

typedef FORMANTS_FLOAT sample;

#define PI 3.1415926535897932384626433832795028841971693993751058209749445923078164062

#define complex_t       NS(complex_t)
#define lpc_work_t      NS(lpc_work_t)
#define lpc_t           NS(lpc_t)
#define root_solver_t   NS(root_solver_t)
#define work_t          NS(work_t)

#define cplx        NS(make_complex)
#define cplx_real   NS(complex_real)
#define cplx_imag   NS(complex_imag)
#define cplx_add    NS(complex_add)
#define cplx_sub    NS(complex_sub)
#define cplx_mul    NS(complex_mul)
#define cplx_div    NS(complex_div)
#define cplx_abs    NS(complex_abs)
#define cplx_arg    NS(complex_arg)

#define formants_make_window                                NS(make_window)
#define formants_destroy_lpc_work                           NS(destroy_lpc_work)
#define formants_make_lpc                                   NS(make_lpc)
#define formants_destroy_lpc                                NS(destroy_lpc)
#define formants_analyze_lpc                                NS(analyze_lpc)
#define formants_make_root_solver                           NS(make_root_solver)
#define formants_destroy_root_solver                        NS(destroy_root_solver)
#define formants_solve_roots                                NS(solve_roots)
#define formants_make_work                                  NS(make_work)
#define formants_destroy_work                               NS(destroy_work)
#define formants_analyze                                    NS(analyze)
#define formants_destroy                                    NS(destroy)

#ifdef __cplusplus
extern "C" {
#endif

#include <complex.h>

#ifdef _MSC_VER
typedef _Dcomplex complex_t;
#else
typedef double complex complex_t;
#endif

typedef struct lpc_work_t {
    sample *b1, *b2, *aa, *win;
    unsigned long length;
    unsigned long order;
} lpc_work_t;

typedef struct lpc_t {
    sample *data;
    unsigned long length;
    unsigned long order;
    lpc_work_t *work;
} lpc_t;

typedef struct root_solver_t {
    complex_t *roots;
    unsigned long degree;
} root_solver_t;

typedef struct work_t {
    lpc_t *lpc;
    root_solver_t *rootSolver;
    unsigned long length;
    unsigned long order;
} work_t;

typedef struct formant_t {
    sample frequency;
    sample bandwidth;
} formant_t;

complex_t cplx(sample x, sample y);
sample cplx_real(complex_t z);
sample cplx_imag(complex_t z);
complex_t cplx_add(complex_t a, complex_t b);
complex_t cplx_sub(complex_t a, complex_t b);
complex_t cplx_mul(complex_t a, complex_t b);
complex_t cplx_div(complex_t a, complex_t b);
sample cplx_abs(complex_t z);
sample cplx_arg(complex_t z);

lpc_work_t *formants_make_lpc_work(unsigned long length, unsigned long order);

void formants_destroy_lpc_work(lpc_work_t *lpcWork);

lpc_t *formants_make_lpc(unsigned long length, unsigned long order);

void formants_destroy_lpc(lpc_t *lpc);

void formants_analyze_lpc(lpc_t *lpc, const sample *input, unsigned long length);

root_solver_t *formants_make_root_solver(unsigned long degree);

void formants_destroy_root_solver(root_solver_t *solver);

void formants_solve_roots(root_solver_t *solver, const sample *coefs, unsigned long degree);

formant_t *formants_calculate_from_roots(const complex_t *roots,
                                            unsigned long rootCount,
                                            sample sampleRate,
                                            sample margin,
                                            unsigned long *formantCount);

void formants_destroy(formant_t *formants);

work_t *formants_make_work(unsigned long length, unsigned long order);

void formants_destroy_work(work_t *work);

formant_t *formants_analyze(work_t *work,
                            const sample *input,
                            unsigned long length,
                            unsigned long order,
                            sample sampleRate,
                            sample margin,
                            unsigned long *formantCount);

void formants_sort(formant_t *formants, unsigned long formantCount);

#ifdef __cplusplus
}
#endif

#ifdef FORMANTS_IMPLEMENTATION

#ifdef __cplusplus
extern "C" {
#endif

#include <assert.h>
#include <stdlib.h>
#include <stdio.h>
#include <math.h>

#ifdef _MSC_VER

complex_t cplx(sample x, sample y)
{
    return _Cbuild(x, y);
}

sample cplx_real(complex_t z)
{
    return creal(z);
}

sample cplx_imag(complex_t z)
{
    return cimag(z);
}

complex_t cplx_add(complex_t a, complex_t b)
{
    return _Cbuild(
        creal(a) + creal(b),
        cimag(a) + cimag(b)
    );
}

complex_t cplx_sub(complex_t a, complex_t b)
{
    return _Cbuild(
        creal(a) - creal(b),
        cimag(a) - cimag(b)
    );
}

complex_t cplx_mul(complex_t a, complex_t b)
{
    return _Cmulcc(a, b);
}

complex_t cplx_div(complex_t a, complex_t b)
{
    return _Cmulcc(a, cpow(b, _Cbuild(-1.0, 0.0)));
}

sample cplx_abs(complex_t z)
{
    return cabs(z);
}

sample cplx_arg(complex_t z)
{
    return carg(z);
}

#else // !_MSC_VER

complex_t cplx(sample x, sample y)
{
    return x + _Complex_I * y;
}

sample cplx_real(complex_t z)
{
    return creal(z);
}

sample cplx_imag(complex_t z)
{
    return cimag(z);
}

complex_t cplx_add(complex_t a, complex_t b)
{
    return a + b;
}

complex_t cplx_sub(complex_t a, complex_t b)
{
    return a - b;
}

complex_t cplx_mul(complex_t a, complex_t b)
{
    return a * b;
}

complex_t cplx_div(complex_t a, complex_t b)
{
    return a / b;
}

sample cplx_abs(complex_t z)
{
    return cabs(z);
}

sample cplx_arg(complex_t z)
{
    return carg(z);
}

#endif // _MSC_VER

lpc_work_t *formants_make_lpc_work(unsigned long length, unsigned long order)
{
    lpc_work_t *lpcWork = (lpc_work_t *) malloc(sizeof(lpc_work_t));
    if (lpcWork) {
        lpcWork->length = length;
        lpcWork->order = order;
        lpcWork->b1 = (sample *) malloc((1 + length) * sizeof(sample));
        lpcWork->b2 = (sample *) malloc((1 + length) * sizeof(sample));
        lpcWork->aa = (sample *) malloc((1 + order) * sizeof(sample));
        lpcWork->win = (sample *) malloc(length * sizeof(sample));
        const sample edge = exp(-12.0);
        for (unsigned long i = 0; i < length; ++i) {
            const sample imid = 0.5 * (length + 1);
            lpcWork->win[i] = (exp(-48.0 * (i - imid) * (i - imid) / (length + 1) / (length + 1)) - edge);
        }
    }
    return lpcWork;
}

void formants_destroy_lpc_work(lpc_work_t *lpcWork)
{
    if (lpcWork) {
        free(lpcWork->b1);
        free(lpcWork->b2);
        free(lpcWork->aa);
        free(lpcWork->win);
        free(lpcWork);
    }
}

lpc_t *formants_make_lpc(unsigned long length, unsigned long order)
{
    lpc_t *lpc = (lpc_t *) malloc(sizeof(lpc_t));
    if (lpc) {
        lpc->data = (sample *) malloc(order * sizeof(sample));
        lpc->length = length;
        lpc->order = order;
        lpc->work = formants_make_lpc_work(length, order);
    }
    return lpc;
}

void formants_destroy_lpc(lpc_t *lpc)
{
    if (lpc) {
        free(lpc->data);
        formants_destroy_lpc_work(lpc->work);
        free(lpc);
    }
}

void formants_analyze_lpc(lpc_t *lpc, const sample *input, unsigned long length)
{
    assert(length == lpc->length);

    const unsigned long n = lpc->length;
    const unsigned long m = lpc->order;

    sample *b1 = lpc->work->b1;
    sample *b2 = lpc->work->b2;
    sample *aa = lpc->work->aa;

    unsigned long i, j;
    for (i = 0; i < 1 + n; ++i) {
        b1[i] = 0.0;
        b2[i] = 0.0;
    }
    for (i = 0; i < 1 + m; ++i) {
        aa[i] = 0.0;
    }
    for (i = 0; i < m; ++i) {
        lpc->data[i] = 0.0;
    }

    sample *a = &lpc->data[-1];
    const sample *x = &input[-1];

    sample p = 0.0;
    for (j = 1; j <= n; ++j) {
        p += x[j] * x[j];
    }

    double xms = p / n;
    if (xms <= 0.0) {
        goto end;
    }

    b1[1] = x[1];
    b2[n - 1] = x[n];
    for (j = 2; j <= n - 1; ++j)
        b1[j] = b2[j - 1] = x[j];

    for (i = 1; i <= m; ++i) {
        sample num = 0.0, denum = 0.0;
        for (j = 1; j <= n - i; ++j) {
            num += b1[j] * b2[j];
            denum += b1[j] * b1[j] + b2[j] * b2[j];
        }

        if (denum <= 0.0) {
            xms = 0.0;
            goto end;
        }

        a[i] = 2.0 * num / denum;

        xms *= 1.0 - a[i] * a[i];

        for (j = 1; j <= i - 1; ++j)
            a[j] = aa[j] - a[i] * aa[i - j];

        if (i < m) {
            for (j = 1; j <= i; ++j)
                aa[j] = a[j];
            for (j = 1; j <= n - i - 1; ++j) {
                b1[j] -= aa[i] * b2[j];
                b2[j] = b2[j + 1] - aa[i] * b1[j + 1];
            }
        }
    }

end:
    for (i = 0; i < m; ++i) {
        lpc->data[i] *= -1;
    }
}

root_solver_t *formants_make_root_solver(unsigned long degree)
{
    root_solver_t *solver = (root_solver_t *) malloc(sizeof(root_solver_t));
    if (solver) {
        solver->degree = degree;
        solver->roots = (complex_t *) malloc(degree * sizeof(complex_t));
    }
    return solver;
}

void formants_destroy_root_solver(root_solver_t *solver)
{
    if (solver) {
        free(solver->roots);
        free(solver);
    }
}

static sample formants__rand_float()
{
    return (rand() - RAND_MAX / 2) * (1.0 / ((sample) RAND_MAX));
}

void formants__init_root_solver(complex_t *roots, const sample *coefs, unsigned long degree)
{
    sample maxUpper = 0.0;
    sample maxLower = 1.0;
    for (unsigned long i = 1; i < degree + 1; ++i) {
        const sample absPi = fabs(coefs[i - 1]);
        if (i >= 1 && absPi > maxUpper)
            maxUpper = absPi;
        else if (i < degree && absPi > maxLower)
            maxLower = absPi;
    }

    const sample upper = 1.0 + maxUpper;
    const sample lower = fabs(coefs[degree - 1]) / (fabs(coefs[degree - 1]) + maxLower);

    for (unsigned long i = 0; i < degree; ++i) {
        const sample r = lower + (upper - lower) * formants__rand_float();
        const sample theta = 2 * PI * formants__rand_float();

        roots[i] = cplx(r * cos(theta), r * sin(theta));
    }
}

void formants__evaluate_monic_polynomial_and_derivative(const sample *coefs, unsigned long degree, const complex_t x, complex_t *y, complex_t *dy)
{
    unsigned long i;
    *y = cplx(1.0, 0.0);
    *dy = cplx(0.0, 0.0);
    for (i = 1; i <= degree; ++i) {
        *dy = cplx_add(cplx_mul(*dy, x), *y);
        *y = cplx_add(cplx_mul(*y, x), cplx(coefs[i - 1], 0.0));
    }
}

void formants_solve_roots(root_solver_t *solver, const sample *coefs, unsigned long degree)
{
    assert(degree == solver->degree);

    formants__init_root_solver(solver->roots, coefs, degree);
    unsigned long iteration = 0;
    unsigned long valid, k, j;

    complex_t y, dy, ratio, sum, offset;

    while (1) {
        valid = 0;
        for (k = 0; k < degree; ++k) {
            formants__evaluate_monic_polynomial_and_derivative(coefs, degree, solver->roots[k], &y, &dy);
            ratio = cplx_div(y, dy);
            
            sum = cplx(0.0, 0.0);
            for (j = 0; j < degree; ++j) {
                if (j != k) {
                    sum = cplx_add(sum, cplx_div(cplx(1.0, 0.0), cplx_sub(solver->roots[k], solver->roots[j])));
                }
            }

            offset = cplx_div(ratio, cplx_sub(cplx(1.0, 0.0), cplx_mul(ratio, sum)));
            if (fabs(cplx_real(offset)) < 1e-4 && fabs(cplx_imag(offset)) < 1e-4) {
                valid++;
            }
            if (isnan(cplx_real(offset)) || isnan(cplx_imag(offset))) {
                valid++;
                continue;
            }
            solver->roots[k] = cplx_sub(solver->roots[k], offset);
        }
        if (valid == degree) {
            break;
        }
        iteration++;
    }
}

formant_t *formants_calculate_from_roots(const complex_t *roots, unsigned long rootCount, sample sampleRate, sample margin, unsigned long *formantCount)
{
    size_t formantsLen = rootCount / 2;
    formant_t *formants = (formant_t *) malloc(formantsLen * sizeof(formant_t));
    unsigned long k = 0;
    for (unsigned long i = 0; i < rootCount && k < formantsLen; ++i) {
        if (cplx_imag(roots[i]) < 0)
            continue;

        const sample r = cplx_abs(roots[i]);
        const sample theta = cplx_arg(roots[i]);

        if (r >= 0.7 && r < 1.0) {
            const sample frequency = (fabs(theta) * sampleRate) / (2.0 * PI);
            if (frequency > margin && frequency < sampleRate / 2.0 - margin) {
                const sample bandwidth = -log(r) * sampleRate / PI;
                formants[k] = (formant_t) {frequency, bandwidth};
                k++;
            }
        }
    }
    *formantCount = k;
    return formants;
}

void formants_destroy(formant_t *formants) {
    free(formants);
}

work_t *formants_make_work(unsigned long length, unsigned long order)
{
    work_t *work = (work_t *) malloc(sizeof(work_t));
    if (work) {
        work->length = length;
        work->order = order;
        work->lpc = formants_make_lpc(length, order);
        work->rootSolver = formants_make_root_solver(order);
    }
    return work;
}

void formants_destroy_work(work_t *work)
{
    if (work) {
        formants_destroy_lpc(work->lpc);
        formants_destroy_root_solver(work->rootSolver);
        free(work);
    }
}

formant_t *formants_analyze(work_t *work, const sample *input, unsigned long length, unsigned long order, sample sampleRate, sample margin, unsigned long *formantCount)
{
    if (length != work->length || order != work->order) {
        formants_destroy_lpc(work->lpc);
        work->lpc = formants_make_lpc(length, order);
    }
    if (order != work->order) {
        formants_destroy_root_solver(work->rootSolver);
        work->rootSolver = formants_make_root_solver(order);
    }
    work->length = length;
    work->order = order;

    formants_analyze_lpc(work->lpc, input, length);
    formants_solve_roots(work->rootSolver, work->lpc->data, order);
    
    formant_t *formants = formants_calculate_from_roots(work->rootSolver->roots, work->order, sampleRate, margin, formantCount);
    formants_sort(formants, *formantCount);
    return formants;
}

int formants__compare_frequency(const void *va, const void *vb)
{
    return (int) copysign(1.0, ((formant_t *) va)->frequency - ((formant_t *) vb)->frequency);
}

void formants_sort(formant_t *formants, unsigned long formantCount)
{
    qsort(formants, formantCount, sizeof(formant_t), &formants__compare_frequency);
}

#ifdef __cplusplus
}
#endif

#endif

#endif // _GUARD_LIBFORMANTS_H
