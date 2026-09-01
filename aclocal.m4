#
# Include the TEA standard macro set
#

builtin(include,tclconfig/tcl.m4)

#
# Add here whatever m4 macros you want to define for your package
#

dnl Helper macros
AC_DEFUN([TEAX_LAPPEND], [$1="[$]{$1} $2"])
AC_DEFUN([TEAX_FOREACH], [for $1 in $2; do $3; done])
AC_DEFUN([TEAX_IFEQ], [AS_IF([test "x$1" = "x$2"], [$3])])
AC_DEFUN([TEAX_IFNEQ], [AS_IF([test "x$1" != "x$2"], [$3])])
AC_DEFUN([TEAX_SWITCH], [case "$1" in TEAX_SWITCH_Cases(m4_shift($@)) esac])
AC_DEFUN([TEAX_SWITCH_Cases], [m4_if([$#],0,,[$#],1,,[TEAX_SWITCH_OneCase($1,$2)TEAX_SWITCH_Cases(m4_shift(m4_shift($@)))])])
AC_DEFUN([TEAX_SWITCH_OneCase],[ $1) $2;;])
AC_DEFUN([CygPath],[`${CYGPATH} $1`])

dnl Interesting macros
AC_DEFUN([TEAX_SUBST_RESOURCE], [
    AC_REQUIRE([TEA_CONFIG_CFLAGS])dnl
    TEAX_IFEQ($TEA_PLATFORM, windows, [
	AC_CHECK_PROGS(RC_, 'windres -o' 'rc -nologo -fo', none)
	TEAX_SWITCH($RC_,
	    windres*, [
		rcdef_inc="--include "
		rcdef_start="--define "
		rcdef_q='\"'
		AC_SUBST(RES_SUFFIX, [res.o])
		TEAX_LAPPEND(PKG_OBJECTS, ${PACKAGE_NAME}.res.o)],
	    rc*, [
		rcdef_inc="-i "
		rcdef_start="-d "
		rcdef_q='"'
		AC_SUBST(RES_SUFFIX, [res])
		TEAX_LAPPEND(PKG_OBJECTS, ${PACKAGE_NAME}.res)],
	    *, [
		AC_MSG_WARN([could not find resource compiler])
		RC_=: ])])
    # This next line is because of the brokenness of TEA...
    AC_SUBST(RC, $RC_)
    TEAX_FOREACH(i, $1, [
	TEAX_LAPPEND(RES_DEFS, ${rcdef_inc}\"CygPath($i)\")])
    TEAX_FOREACH(i, $2, [
	TEAX_LAPPEND(RES_DEFS, ${rcdef_start}$i='${rcdef_q}\$($i)${rcdef_q}')])
    AC_SUBST(RES_DEFS)])
AC_DEFUN([TEAX_ADD_PRIVATE_HEADERS], [
    TEAX_FOREACH(i, $@, [
	# check for existence, be strict because it should be present!
	AS_IF([test ! -f "${srcdir}/$i"], [
	    AC_MSG_ERROR([could not find header file '${srcdir}/$i'])])
	TEAX_LAPPEND(PKG_PRIVATE_HEADERS, $i)])
    AC_SUBST(PKG_PRIVATE_HEADERS)])

AC_DEFUN([TEAX_SDX], [
    AC_PATH_PROG(SDX, sdx, none)
    TEAX_IFEQ($SDX, none, [
	AC_PATH_PROG(SDX_KIT, sdx.kit, none)
	TEAX_IFNEQ($SDX_KIT, none, [
	    # We assume that sdx.kit is on the path, and that the default
	    # tclsh is activetcl
	    SDX="tclsh '${SDX_KIT}'"])])
    TEAX_IFEQ($SDX, none, [
	AC_MSG_WARN([cannot find sdx; building starkits will fail])
	AC_MSG_NOTICE([building as a normal library still supported])])])
dnl TODO: Adapt this for OSX Frameworks...
dnl This next bit is a bit ugly, but it makes things for tclooConfig.sh...
AC_DEFUN([TEAX_PATH_LINE], [
    eval "$1=\"[]CygPath($2)\""
    AC_SUBST($1)])
AC_DEFUN([TEAX_INCLUDE_LINE], [
    eval "$1=\"-I[]CygPath($2)\""
    AC_SUBST($1)])
AC_DEFUN([TEAX_LINK_LINE], [
    AS_IF([test ${TCL_LIB_VERSIONS_OK} = nodots], [
	eval "$1=\"-L[]CygPath($2) -l$3${TCL_TRIM_DOTS}\""
    ], [
	eval "$1=\"-L[]CygPath($2) -l$3${PACKAGE_VERSION}\""
    ])
    AC_SUBST($1)])

dnl Compile in an absolute path to the client library, which
dnl PostgresqlInitStubs() tries before searching by bare name.  Needed on
dnl macOS, where dlopen() searches neither /opt/homebrew nor /usr/local/lib,
dnl and where DYLD_LIBRARY_PATH is stripped from hardened processes.  The
dnl opt/*/lib entries cover package managers that keep a formula unlinked.
dnl Must be called after TEA_CONFIG_CFLAGS, which sets SHLIB_SUFFIX.
AC_DEFUN([TEAX_PQ_CLIENT_LIBRARY], [
    AC_ARG_WITH([pq-library],
	AS_HELP_STRING([--with-pq-library=FILE],
	    [absolute path of the PostgreSQL client library, libpq, to try
	     first at run time; "no" to disable, default is to search]),
	[teax_pq_lib=$withval], [teax_pq_lib=auto])
    AS_CASE([$teax_pq_lib],
	[no], [teax_pq_lib=""],
	[auto|yes], [
	    AC_MSG_CHECKING([for a client library to compile in])
	    teax_pq_lib=""
	    for teax_dir in ${HOMEBREW_PREFIX:+$HOMEBREW_PREFIX/opt/libpq/lib} \
		    /opt/homebrew/opt/libpq/lib /opt/homebrew/opt/postgresql*/lib \
		    /opt/homebrew/lib /usr/local/opt/libpq/lib \
		    /usr/local/lib /opt/local/lib /usr/local/pgsql/lib ; do
		for teax_try in "$teax_dir/libpq$SHLIB_SUFFIX" \
			"$teax_dir/libpq".*"$SHLIB_SUFFIX" ; do
		    AS_IF([test -f "$teax_try"], [
			teax_pq_lib=$teax_try
			break 2])
		done
	    done
	    AS_IF([test -n "$teax_pq_lib"],
		[AC_MSG_RESULT([$teax_pq_lib])],
		[AC_MSG_RESULT([none, will search by name at run time])])],
	[*], [
	    AS_IF([test -f "$teax_pq_lib"], [],
		[AC_MSG_ERROR([no such file: $teax_pq_lib])])])
    AS_IF([test -n "$teax_pq_lib"], [
	AC_DEFINE_UNQUOTED([PQ_CLIENT_LIBRARY], ["$teax_pq_lib"],
	    [Client library to load before searching by name.])])])

dnl Local Variables:
dnl mode: autoconf
dnl End:
