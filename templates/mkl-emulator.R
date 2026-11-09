# Varies the summation order of each matrix product, as a BLAS may. See guides/blas-failures.md.
# Copy into R/ of a scratch copy of the package, and run its tests with MKL_EMUL=1.
.mkl_emul <- new.env(parent = emptyenv())
.mkl_perm <- function(K) {            # call-counter driven, no RNG
	if (is.null(.mkl_emul$n)) .mkl_emul$n <- as.numeric(Sys.getenv("MKL_EMUL_START", "0"))
	.mkl_emul$n <- .mkl_emul$n + 1; if (K < 3L) return(seq_len(K)); n <- .mkl_emul$n
	r <- floor(K * ((n * 0.6180339887498949) %% 1))
	p <- if (r == 0) seq_len(K) else c((r + 1L):K, seq_len(r))
	if (((n * 0.4142135623730951) %% 1) > 0.5) p <- rev(p); p
}
.mkl_plain <- function(a) is.numeric(a) && !isS4(a) && !is.object(a)
`%*%` <- function(x, y) {
	if (identical(Sys.getenv("MKL_EMUL"), "1") && .mkl_plain(x) && .mkl_plain(y)) {
		dx <- dim(x); dy <- dim(y)
		if (length(dx) == 2L && length(dy) == 2L && dx[2L] == dy[1L]) { p <- .mkl_perm(dx[2L]); return(base::`%*%`(x[, p, drop = FALSE], y[p, , drop = FALSE])) }
		if (length(dx) == 2L && is.null(dy) && dx[2L] == length(y)) { p <- .mkl_perm(dx[2L]); return(base::`%*%`(x[, p, drop = FALSE], y[p])) }
		if (is.null(dx) && length(dy) == 2L && length(x) == dy[1L]) { p <- .mkl_perm(dy[1L]); return(base::`%*%`(x[p], y[p, , drop = FALSE])) }
		if (is.null(dx) && is.null(dy) && length(x) == length(y)) { p <- .mkl_perm(length(x)); return(base::`%*%`(x[p], y[p])) }
	}
	base::`%*%`(x, y)
}
crossprod <- function(x, y = NULL) {
	if (identical(Sys.getenv("MKL_EMUL"), "1") && .mkl_plain(x) && (is.null(y) || .mkl_plain(y))) {
		dx <- dim(x); dy <- dim(y)
		if (is.null(y)) {
			if (length(dx) == 2L) { p <- .mkl_perm(dx[1L]); return(base::crossprod(x[p, , drop = FALSE])) }
			if (is.null(dx)) { p <- .mkl_perm(length(x)); return(base::crossprod(x[p])) }
		} else {
			if (length(dx) == 2L && length(dy) == 2L && dx[1L] == dy[1L]) { p <- .mkl_perm(dx[1L]); return(base::crossprod(x[p, , drop = FALSE], y[p, , drop = FALSE])) }
			if (length(dx) == 2L && is.null(dy) && dx[1L] == length(y)) { p <- .mkl_perm(dx[1L]); return(base::crossprod(x[p, , drop = FALSE], y[p])) }
			if (is.null(dx) && length(dy) == 2L && length(x) == dy[1L]) { p <- .mkl_perm(dy[1L]); return(base::crossprod(x[p], y[p, , drop = FALSE])) }
			if (is.null(dx) && is.null(dy) && length(x) == length(y)) { p <- .mkl_perm(length(x)); return(base::crossprod(x[p], y[p])) }
		}
	}
	if (is.null(y)) base::crossprod(x) else base::crossprod(x, y)
}
tcrossprod <- function(x, y = NULL) {
	if (identical(Sys.getenv("MKL_EMUL"), "1") && .mkl_plain(x) && (is.null(y) || .mkl_plain(y))) {
		dx <- dim(x); dy <- dim(y)
		if (is.null(y)) {
			if (length(dx) == 2L) { p <- .mkl_perm(dx[2L]); return(base::tcrossprod(x[, p, drop = FALSE])) }
		} else {
			if (length(dx) == 2L && length(dy) == 2L && dx[2L] == dy[2L]) { p <- .mkl_perm(dx[2L]); return(base::tcrossprod(x[, p, drop = FALSE], y[, p, drop = FALSE])) }
			if (length(dx) == 2L && is.null(dy) && dx[2L] == length(y)) { p <- .mkl_perm(dx[2L]); return(base::tcrossprod(x[, p, drop = FALSE], y[p])) }
			if (is.null(dx) && length(dy) == 2L && length(x) == dy[2L]) { p <- .mkl_perm(dy[2L]); return(base::tcrossprod(x[p], y[, p, drop = FALSE])) }
		}
	}
	if (is.null(y)) base::tcrossprod(x) else base::tcrossprod(x, y)
}
