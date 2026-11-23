/* LOCAL: IDL (Interactive Data Language, NV5/L3Harris) grammar, for `.pro` files.
   Highlight.js has none. Appended to Sources/Assets/highlight.min.js by
   `cat tools/idl.js >> Sources/Assets/highlight.min.js` after mklazy.js. */
hljs.registerLanguage("idl", function (hljs) {
  const IDENT = /[A-Za-z_][\w$]*/;
  const ROUTINE = /[A-Za-z_][\w$]*(?:::[A-Za-z_][\w$]*)?/;
  return {
    name: "IDL",
    aliases: ["pro"],
    case_insensitive: true,
    keywords: {
      $pattern: IDENT,
      keyword:
        "pro function end endif endelse endfor endforeach endwhile endrep endcase endswitch " +
        "begin if then else for foreach do while repeat until case of switch break continue " +
        "return goto common compile_opt forward_function inherits " +
        "and or not xor eq ne lt le gt ge mod",
      "variable.language": "self",
      built_in:
        // Output, files and I/O
        "print printf help message stop retall wait cd spawn execute call_function call_procedure " +
        "call_method openr openw openu close free_lun get_lun readf readu writeu printu point_lun eof " +
        "file_search file_test file_lines file_basename file_dirname file_mkdir file_delete filepath " +
        "restore save read_ascii read_csv write_csv readcol readfits writefits mrdfits mwrfits " +
        "sxpar fxpar headfits dialog_pickfile journal " +
        // Arguments and types
        "n_elements n_params n_tags keyword_set arg_present size isa typename tag_names " +
        "obj_new obj_destroy obj_valid obj_class obj_isa ptr_new ptr_free ptr_valid " +
        "byte fix uint long ulong long64 ulong64 float double complex dcomplex string boolean " +
        "hash orderedhash list dictionary create_struct " +
        // Arrays
        "bytarr intarr uintarr lonarr ulonarr lon64arr ulon64arr fltarr dblarr complexarr " +
        "dcomplexarr strarr ptrarr objarr make_array replicate " +
        "bindgen indgen uindgen lindgen ulindgen l64indgen findgen dindgen cindgen dcindgen " +
        "where array_indices reform rebin congrid transpose reverse rotate shift sort uniq " +
        "n_elements total product mean median stddev variance moment min max abs sqrt exp " +
        "alog alog10 sin cos tan asin acos atan sinh cosh tanh round floor ceil finite " +
        "histogram interpol interpolate poly_fit linfit curvefit mpfit fft convol smooth " +
        "randomu randomn cumulative invert la_invert matrix_multiply ishft " +
        // Strings
        "strtrim strlen strmid strpos strsplit strjoin strupcase strlowcase strcompress " +
        "strmatch stregex strput strcmp string " +
        // Graphics
        "plot oplot contour surface shade_surf tv tvscl tvrd window wset wdelete wshow device " +
        "loadct tvlct xyouts plots polyfill axis erase set_plot cgplot cgimage " +
        "image colorbar legend text polygon polyline " +
        // Errors and timing
        "catch on_error on_ioerror systime tic toc",
    },
    contains: [
      hljs.COMMENT(";", "$"),
      // Executive commands and batch files: `.compile foo`, `@setup`
      { scope: "meta", match: /^\s*\.[A-Za-z_]+\b.*$/ },
      { scope: "meta", match: /^\s*@\S+/ },
      // `pro name, ...`, `function class::method, ...`
      {
        match: [/\b(?:pro|function)\b/, /\s+/, ROUTINE],
        scope: { 1: "keyword", 3: "title.function" },
      },
      // `compile_opt idl2, strictarr`
      {
        match: [/\bcompile_opt\b/, /[^;\n]*/],
        scope: { 1: "keyword", 2: "meta" },
      },
      // Quoted hex, octal and binary integers: '0F'x, '17'o, '101'b
      { scope: "number", match: /'[0-9a-f]+'x(?:ull|ul|us|ll|[bslu])?(?![\w$])/ },
      { scope: "number", match: /'[0-7]+'o(?:ull|ul|us|ll|[bslu])?(?![\w$])/ },
      { scope: "number", match: /'[01]+'b(?:ull|ul|us|ll|[bslu])?(?![\w$])/ },
      // "17 is octal when no closing quote follows on the line
      { scope: "number", match: /"[0-7]+(?:ull|ul|us|ll|[bslu])?(?![\w$"])(?![^"\n]*")/ },
      {
        scope: "string",
        variants: [
          { begin: "'", end: /'|$/, contains: [{ match: "''" }] },
          { begin: '"', end: /"|$/, contains: [{ match: '""' }] },
        ],
      },
      {
        scope: "number",
        variants: [
          { match: /\b0x[0-9a-f]+(?:ull|ul|us|ll|[bslu])?(?![\w$])/ },
          { match: /\b0o[0-7]+(?:ull|ul|us|ll|[bslu])?(?![\w$])/ },
          { match: /\b0b[01]+(?:ull|ul|us|ll|[bslu])?(?![\w$])/ },
          { match: /(?:\b\d+\.?\d*|\.\d+)(?:[ed][+-]?\d*)?(?:ull|ul|us|ll|[bslu])?(?![\w$])/ },
        ],
      },
      // System variables: !pi, !values.f_nan, !null
      { scope: "variable.language", match: /![A-Za-z_][\w$]*/ },
      // Keyword arguments: `, /QUIET` and `, NAME=value`
      { match: [/,\s*/, /\/[A-Za-z_][\w$]*/], scope: { 2: "attr" } },
      { match: [/[,(]\s*/, IDENT, /\s*=(?!=)/], scope: { 2: "attr" } },
      // Method calls: `obj->method`, `self->parent::init`
      { match: [/->/, ROUTINE], scope: { 2: "title.function.invoke" } },
    ],
  };
});
