% rst.sl
% ======
% 
% Mode for reStructured Text (from Python docutils__)
% 
% Copyright (c) 2004, 2006 Guenter Milde (milde users.sf.net)
% Released under the terms of the GNU General Public License (ver. 2 or later)
% 
% `ReStructured Text`__ is a revision of Structured Text, a simple markup
% language that can be translated to Html and LaTeX (and more, if someone
% writes a converter)
% 
% __ http://docutils.sourceforge.net/
% __ http://docutils.sourceforge.net/docs/rst/quickref.html
% 
% Versions
% ========
% 
% ===== ========== ============================================================
% 1.1   2004-10-18 initial attempt
% 1.2   2004-12-23 removed dependency on view mode (called by runhooks now)
% 1.2.1 2005-03-11 bugfix in Mode>Layout>Hrule
%                  bugfix remove spurious ":" from anonymous target markup
% 1.3   2005-04-14 restructuring of the export and view functions
% 1.3.1 2005-11-02 hide "public" in some functions
% 1.3.2 2005-11-08 changed _implements() to implements()
% 1.3.3 2006-01-09 separated Html and Latex output options
% 1.4   2006-03-29 improved syntax highlight
%                  removed dependency on ishell.sl
%                  merged export help into set_rst2*_options()
%                  nagivation buffer with tokenlist
% 1.4.1 2006-05-18 fix syntax for sub- and supscript
%                  conservative highlight of list markers
% 1.4.2 2006-05-26 fixed autoloads (J. Sommer)
% 1.5              new menu entry names matching the docutils use of terms
% 1.5.1 2006-08-14 Adapted to structured_text v. 0.5 (do not call text_mode()).
% 1.5.2 2006-11-27 Bugfix: let rst_mode() really call the structured_text_hook
% 1.6   2006-11-28 Drop the .py ending from the Rst2* custom variables defaults
%                  use do_shell_cmd() for error redirection
% 1.7   2007-02-06 * Removed the Rst2*_Options custom variables.
%                    (Set the command line options in Rst2*_Cmd and change
%                    with set_export_options(cmd) (or from Mode menu))
%                  * "Directives" menu entry (incomplete)
%                  * Support PDF export with rst2pdf.py
%                  * Menu entries to browse docutils html documentation with
%                    browse_url() (you probabely need to set
%                    Rst_Documentation_Path on non Debian systems)
%                  * goto error line from export output buffer (with filelist)
%                  * section_markup(): go up if standing at the underline
%                  * Erase the export output buffer before exporting
%                  * rename rst_list_routines_hook() to
%                    rst_list_routines_done() to match the new tokenlist.sl
% 1.7.1 2007-02-26 * the rst2pdf.py script did not work. It is replaced by
%                    `py.rest --topdf`.
% 1.8   2007-03-13 Replace set_export_options() with set_export_cmd()
% 1.8.1 2007-03-30 Unit testing and fixes
% 1.8.2 2007-05-14 * removed leading \n from Markup_Tags, 
%                    (handled by insert_block_markup() since textutils 2.6.3)
%                  * simplified dfa rules using ""R string suffix
%                  * rst_levels: use String instead of List
% 1.9   2007-07-23 * rename section_markup() to section_header(), allow 
%                    integer arguments (section level)
%                  * new functions rst_view() and rst_view_html(), 
%                    rst_view_pdf, rst_view_latex obsoleting rst_browse()
% 
% ===== ========== ============================================================
% 
% 
% TODO: directives functions (see /docutils/docs/ref/rst/directives.html)
% 
% 
% Requirements
% ============
% 
% standard modes::

require("comments");

% extra modes (from http://jedmodes.sf.net/mode/)::

autoload("structured_text_hook", "structured_text");  % >= 0.5
autoload("push_defaults", "sl_utils");
autoload("push_array", "sl_utils");
autoload("prompt_for_argument", "sl_utils");
autoload("get_blocal", "sl_utils");
autoload("popup_buffer", "bufutils");
autoload("buffer_dirname", "bufutils");
autoload("close_buffer", "bufutils");
autoload("fit_window", "bufutils");
autoload("run_buffer", "bufutils");
autoload("insert_markup", "txtutils");   % >= 2.3
autoload("insert_block_markup", "txtutils");   % >= 2.3
autoload("string_repeat", "strutils");

% Recommendations
% ===============
% 
% jump to the error locations from output buffer::

#if (expand_jedlib_file("filelist.sl") != "")
autoload("filelist_mode", "filelist");
#endif

% browse the html rendering in a separate browser, browse documentation::

#if (expand_jedlib_file("browse_url.sl") != "")
autoload("browse_url", "browse_url");
#endif

% navigation buffer (navigable table of contents)::

#if (expand_jedlib_file("tokenlist.sl") != "")
autoload("list_routines", "tokenlist");
#endif

% name it
% =======
% ::

provide("rst");
implements("rst");
private variable mode = "rst";


% Variables
% =========
% 
% ::

% Custom Variables
% ----------------
% 
% ::

%!%+
%\variable{Rst2Html_Cmd}
%\synopsis{ReStructured Text to Html converter}
%\usage{String_Type Rst2Html_Cmd = "rst2html"}
%\description
% Shell command and options for the ReStructured Text to Html converter
%
% Command and options can be changed from the "Mode>Set Export Cmd >>>" menu
% popup. However, these changes are only valid for the current jed session.
% Permanent changes should be done by defining the variable in the jed.rc
% file.
%\notes
% The default works if the executable `rst2html` is installed in the
% PATH (e.g. with the Debian package python-docutils.deb).
%\seealso{rst_mode, Rst2Latex_Cmd, Rst2Pdf_Cmd}
%!%-
custom_variable("Rst2Html_Cmd", "rst2html");

%!%+
%\variable{Rst2Latex_Cmd}
%\synopsis{ReStructured Text to LaTeX converter}
%\usage{String_Type Rst2Latex_Cmd = "rst2latex"}
%\description
% Shell command and options for the ReStructured Text to LaTeX converter.
%
% Command and options can be changed from the "Mode>Set Export Cmd >>>" menu
% popup. However, these changes are only valid for the current jed session.
% Permanent changes should be done by defining the variable in the jed.rc
% file.
%\notes
% The default works if the executable `rst2latex` is installed in the
% PATH (e.g. with the Debian package python-docutils.deb).
%\seealso{rst_mode, Rst2Pdf_Cmd, Rst2Html_Cmd}
%!%-
custom_variable("Rst2Latex_Cmd", "rst2latex");

%!%+
%\variable{Rst2Pdf_Cmd}
%\synopsis{ReStructured Text to LaTeX converter}
%\usage{String_Type Rst2Pdf_Cmd = "rst2pdf.py"}
%\description
% Shell command and options for the ReStructured Text to LaTeX converter.
%
% Command and options can be changed from the "Mode>Set Export Cmd >>>" menu
% popup. However, these changes are only valid for the current jed session.
% Permanent changes should be done by defining the variable in the jed.rc
% file.
%\notes
% The default works if the executable `py.rest` is installed in the
% PATH (e.g. with the Debian package `python-codespeak-lib`).
%\seealso{rst_mode, Rst2Pdf_Cmd, Rst2Html_Cmd}
%!%-
custom_variable("Rst2Pdf_Cmd", "py.rest --topdf");

%!%+
%\variable{Rst_Documentation_Path}
%\synopsis{Base URL of the Docutils Project Documentation}
%\usage{variable Rst_Documentation_Path = "file:/usr/share/doc/python-docutils/docs/"}
%\description
%  Pointer to the Docutils Project Documentation
%  which will be opened by the Mode>Help>Doc Overview menu entry.
%
%  The default works with the Debian "python-docutils" package.
%  Set to your local documentation mirror or "http://docutils.sf.net/docs/"
%\seealso{rst_mode}
%!%-
custom_variable("Rst_Documentation_Path",
   "file:/usr/share/doc/python-docutils/docs/");


%!%+
%\variable{Rst_Html_Viewer}
%\synopsis{External program to view HTML rendering of rst documents}
%\usage{variable Rst_Html_Viewer = "firefox"}
%\description
%  The command started by \sfun{rst_view_html}
%\seealso{Rst_Pdf_Viewer, Rst2Html_Cmd, rst->rst_view, rst_to_html}
%!%-
custom_variable("Rst_Html_Viewer", "firefox");

%!%+
%\variable{Rst_Pdf_Viewer}
%\synopsis{External program to view PDF rendering of rst documents}
%\usage{variable Rst_Pdf_Viewer = "xpdf"}
%  The command started by \sfun{rst_view_pdf}
%\seealso{Rst_Html_Viewer, Rst2Pdf_Cmd, rst->rst_view, rst_to_pdf}
%!%-
custom_variable("Rst_Pdf_Viewer", "xpdf"); 


% Static Variables
% ----------------
% 
% ::

static variable Last_Underline_Char = "=";
static variable Underline_Chars = "*=-~\"'`^:+#<>_";
static variable Underline_Regexp = sprintf("^\([%s]\)+[ \t]*$"R, 
   str_replace_all(Underline_Chars, "-", "\\-"));

private variable helpbuffer = "*rst export help*";

% Pointer to the export command string for a given file extension
private variable export_cmds = Assoc_Type[Ref_Type];
export_cmds["html"] = &Rst2Html_Cmd;
export_cmds["tex"] = &Rst2Latex_Cmd;
export_cmds["pdf"] = &Rst2Pdf_Cmd;

% Markup strings ::

static variable Markup_Tags = Assoc_Type[Array_Type];

% Layout Character (inline)
Markup_Tags["strong"]      = ["**", "**"];     % bold
Markup_Tags["emphasis"]    = ["*",  "*"];      % usually typeset as italics
Markup_Tags["literal"]     = ["``", "``"];     % usually fixed width
Markup_Tags["interpreted"] = ["`", "`"];
Markup_Tags["subscript"]   = [":sub:`", "`"];
Markup_Tags["superscript"] = [":sup:`", "`"];

% Layout Pragraph (block)
Markup_Tags["hrule"]         = ["\n-------------\n", ""];  % transition
Markup_Tags["preformatted"] = ["::\n    ", "\n"];

% References (outgoing links, occure in the text)
Markup_Tags["hyperlink_ref"]           = ["`", "`_"];   % hyperlink, anchor
Markup_Tags["anonymous_hyperlink_ref"] = ["`", "`__"];
Markup_Tags["numeric_footnote_ref"]   = ["",  " [#]_"]; % automatic  numbering
Markup_Tags["symbolic_footnote_ref"]  = ["",  " [*]_"]; % automatic  numbering
Markup_Tags["citation_ref"]           = ["[", "]_"];    % also for footnotes
Markup_Tags["substitution_ref"]       = ["|", "|"];

% Reference Targets
Markup_Tags["hyperlink"]           = [".. _", ":"];   % URL, crossreference
Markup_Tags["anonymous_hyperlink"] = ["__ ", ""];
Markup_Tags["numeric_footnote"]   = [".. [#]", ""];   % automatic  numbering
Markup_Tags["symbolic_footnote"]  = [".. [*]", ""];   % automatic  numbering
Markup_Tags["citation"]           = [".. [", "]"];
Markup_Tags["directive"]          = [".. ", "::"];
Markup_Tags["substitution"]       = [".. |", "|"];

% Functions
% =========
% 
% Export
% ------
% ::

private define get_outfile(format)
{
   variable outfile = path_sans_extname(whatbuf())+ "." + format;
   outfile = path_concat(buffer_dirname(), outfile);
   return outfile;
}

% export the buffer/region to outfile using export_cmds[]
static define rst_export() % (format, outfile=get_outfile(format))
{
   variable format, outfile;
   (format, outfile) = push_defaults( , , _NARGS);

   if (format == NULL)
     format = read_with_completion(strjoin(assoc_get_keys(export_cmds), ","),
      "Export buffer to ", "html", "", 's');
   
   if (outfile == NULL)
     outfile = get_outfile(format);
   else if (outfile != "") % complete path if relative path is given
     outfile = path_concat(buffer_dirname(), outfile);

   % Assemble export command line:
   variable cmd = @export_cmds[format];
   % do not specify outfile for `py.rest`
   if (extract_element(cmd, 0, ' ') == "py.rest")
     outfile = "";
   cmd = strjoin([cmd, buffer_filename(), outfile], " ");
   % return show(cmd);
   
   save_buffer();
   flush("exporting to " + format);
   popup_buffer("*rst export output*");
   set_readonly(0);
   erase_buffer();
   set_prefix_argument(1);
   do_shell_cmd(cmd);
   set_buffer_modified_flag(0);
   if (bobp and eobp)
     close_buffer();
   else
     {
      fit_window(get_blocal("is_popup", 0));
#ifexists filelist_mode
      % jump to the error locations
      define_blocal_var("delimiter", ':');
      define_blocal_var("line_no_position", 1);
      filelist_mode();
#endif
     }

   message("exported to " + outfile);
}

% export to html
public  define rst_to_html()
{
   rst_export("html");
}

% export to LaTeX
public  define rst_to_latex()
{
   rst_export("tex");
}

% export to PDF
public  define rst_to_pdf()
{
     rst_export("pdf");
}


% View output files
% -----------------
% ::

% View the rst document in `format'
static define rst_view() % (format, outfile=get_outfile(format), viewer)
{
   variable format, outfile, viewer;
   (format, outfile, viewer) = push_defaults( , , , _NARGS);

   if (format == NULL)
     format = read_with_completion(strjoin(assoc_get_keys(export_cmds), ","),
      "Export buffer to ", "html", "", 's');
   
   if (outfile == NULL)
     outfile = get_outfile(format);
   else % complete path if relative path is given
     outfile = path_concat(buffer_dirname(), outfile);

   if (viewer == NULL)
   variable cmd_var = sprintf("Rst_%s_Viewer", 
      strup(format[[:0]])+strlow(format[[1:]]));
   if (is_defined(cmd_var))
     viewer = @(__get_reference(cmd_var));
   else
     viewer = "";

   % recreate outfile, if the buffer is newer
   save_buffer();
   if (file_time_compare(buffer_filename(), outfile) > 0)
     rst_export(format, outfile);

   % open outfile with viewer (or in a new buffer, if viewer is empty string)
   if (viewer == "")
     {
        () = find_file(outfile);
        return;
     }
   
   % convert `outfile' to URL if `format' is html
   if (format == "html")
     outfile = "file:" + outfile;
   
   if (getenv("DISPLAY") != NULL) % assume X-Windows running
       () = system(viewer + " " + outfile + " &");
   else
     () = run_program(viewer + " " + outfile);
}

% View the html conversion of the current buffer in an external browser
public  define rst_view_html()
{
   rst_view("html");
}

% Find the LaTeX conversion of the current buffer
public  define rst_view_latex() % (outfile=*.tex, viewer="")
{
   rst_view("tex");
}

% View the pdf conversion of the current buffer with Rst_Pdf_Viewer
public  define rst_view_pdf() % (outfile=*.pdf, viewer=Rst_Pdf_Viewer)
{
   rst_view("pdf");
}


% open popup-buffer with help for cmd
% TODO: this is of more general interest. where to put it?
static define command_help(cmd)
{
   popup_buffer(helpbuffer, 1.0);
   set_prefix_argument(1);
   do_shell_cmd(extract_element(cmd, 0, ' ') + " --help");
   fit_window(get_blocal("is_popup", 0));
   set_buffer_modified_flag(0);
   call_function("view_mode");
   bob();
}

% set Rst2* (export command) command and options for export_type 
% (see private variable export_cmds for available export types, 
%  e.g. "html", "tex", pdf")
static define set_export_cmd(export_type)
{
   variable cmd_var = export_cmds[export_type]; % variable reference
   variable cmd = @cmd_var;
   @cmd_var = read_mini("export cmd and options:", "", cmd);
}

% Markup
% ------
% ::

% insert a markup
static define markup(type)
{
   insert_markup(Markup_Tags[type][0], Markup_Tags[type][1]);
}

% insert markup and (re) indent
static define block_markup(type)
{
   insert_block_markup(Markup_Tags[type][0], Markup_Tags[type][1]);
}


static define insert_directive(name)
{
   !if (bolp())
     newline();
   vinsert(".. %s:: ", name);
}

% underline the current line
% 
% if there is already underlining, adapt it to the lenght of the line
% 
% If the argument is an integer or a string convertible to an integer, is is
% considered the section level. 
% TODO: use existing section level markup 
static define section_header() % ([adornment])
{
   variable adornment = push_defaults( , _NARGS);
   if (adornment == NULL)
     adornment = read_mini(sprintf("Underline char [%s]:", Underline_Chars),
        Last_Underline_Char, "");

   variable len, old_char;
   
   % Convert integer argument to character:
   if (andelse{typeof(adornment) == String_Type}
        {string_match(adornment,"^[0-9]+$" , 1)})
     adornment = integer(adornment);
   if (typeof(adornment) == Integer_Type)
     adornment = char(Underline_Chars[adornment]);

   Last_Underline_Char = adornment;

   % go up to the title line, if at the underline
   bol();
   if (re_looking_at(Underline_Regexp))
     go_up_1();

   % get the title length (trim by the way)
   eol_trim();
   len = what_column();
   if (len == 0) % transition
     len = WRAP;

   !if (right(1))
     newline();
   if (re_looking_at(Underline_Regexp))
       delete_line();

   insert(string_repeat(adornment, len-1) + "\n");
}

% Navigation
% ----------
% 
% Use Marko Mahnics tokenlist to create a navigation buffer with all section
% titles. ::

#ifexists list_routines

%% message("tokenlist present");

% array of regular expressions matching routines
public  variable rst_list_routines_regexp = [Underline_Regexp];

% return section header level of (section title underlined with) `adornment'
% (starting with level 1 == H1)
private variable rst_levels = "";
private define get_rst_level(adornment)
{
   variable i = is_substr(rst_levels, adornment);
   if (i)
     return i;
   rst_levels += adornment;
   return strlen(rst_levels);
}

% rst mode's hook for tkl_list_tokens():
% 
%% tkl_list_tokens searches for a set of regular expressions defined
%% by an array of strings arr_regexp. For every match tkl_list_tokens
%% calls the function defined in the string fn_extract with an integer
%% parameter that is the index of the matched regexp. At the time of the
%% call, the point is at the beginning of the match.
%% 
%% The called function should return a string that it extracts from 
%% the current line.
%
% The returned string is inserted into the tokenlist. We format to get a nice
% list of section titles:
public  define rst_list_routines_extract(regexp_index)
{
   variable adornment, title, level, col;
   
   % point is at first matching adornment character
   % get adornment character (as string) and lenght of underline adornment
   adornment = char(what_char());
   skip_chars(adornment);
   col = what_column();
   % get the section title above the adornment
   !if (up(1))
     return ""; % first line, no section title
   % skip to end of section title
   eol(); bskip_white();
   if (what_column() == 1     % blank line
      or what_column() > col) % underline too short
     return "";  % there is no section title
   push_mark();
   bol_skip_white();
   title =  bufsubstr();

   % Format
   level = get_rst_level(adornment);
     
   % Variants of output formatting::

   % show(level, adornment);

   % do not indent at all (simple, missing information)
   % return(sprintf("%s %s", adornment, title));

   % indent by 1 underline char/level (too noisy)
   % return sprintf("%s %s", string_repeat(adornment, level), title);

   % indetn by 2 underline chars/level (not better)
   % return sprintf("%s %s", string_repeat(adornment, level*2), title);

   % indent by 1 dot/level (still ok)
   % return sprintf("%s %s", string_repeat(".", level), title);

   % indent by 2 dots/level (quite nice)
   % return sprintf("%s %s", string_repeat(".", level*2), title);

   % indent by 2 dots/level, precede with underline char (ugly)
   % return sprintf("%s %s %s", adornment, string_repeat(".", level*2), title);

   % indent by 2 dots/level, underline char as marker  (quite nice, informative)
   % return sprintf(".%s %s %s", string_repeat(".", level*2), adornment, title);

   % indent by 2 spaces/level, underline char as marker (best)
   % needs modified tokenlist that doesnot strip leading whitespace
   return sprintf("%s%s %s", 
      string_repeat(" ", (level-1)*2), adornment, title);
}

public  define rst_list_routines_done()
{
   rst_levels = "";    % reset
}

#endif

% Syntax Highlight
% ================
% ::

create_syntax_table (mode);
define_syntax( '\\', '\\', mode);               % escape character
set_syntax_flags (mode, 0);

% keywords
% admonitions
() = define_keywords_n(mode, "hintnote", 4, 0);
() = define_keywords_n(mode, "attention", 9, 0);

#ifdef HAS_DFA_SYNTAX
%%% DFA_CACHE_BEGIN %%%

% Inline Markup
% 
% The rules for inline markup are stated in quickref.html. They cannot be
% easily and fully translated to DFA syntax, as
% 
%  * in JED, DFA patterns do not cross lines
%  * excluding visible patterns outside the to-be-highlighted region via
%    e.g. [^a-z] will erroneously color allowed chars.
%  * also, [-abc] must be written [\\-abc]
% 
% Therefore only a subset of inline markup will be highlighted correctly. ::

% Felix Wiemann recommendet in a mail at Docutils-users:
% 
%   You can have a look at docutils/parsers/rst/states.py.  It contains all
%   the regular expressions needed to parse reStructuredText, even though
%   they may not be in the format in which you need them.
% 
% ::

private define inline_rule(s)
{
   variable re = "%s([^ \t%s]|[^ \t%s]+[^%s]*[^ \t%s\\\\])%s";
   return sprintf(re, s, s, s, s, s, s);
}

static define setup_dfa_callback(mode)
{
   dfa_enable_highlight_cache(mode +".dfa", mode);

   variable color_strong = "error";
   variable color_emphasis = "string";
   variable color_literal = "preprocess";
   variable color_interpreted = "number";
   variable color_substitution = "keyword1";
   variable color_directive = "keyword1";
   %
   variable color_url = "keyword";
   variable color_email = "keyword";
   variable color_reference = "keyword";
   variable color_target = "keyword";
   variable color_list_marker = "delimiter";
   variable color_transition = "comment";

   % Inline Markup
   dfa_define_highlight_rule(inline_rule("\*"R), "Q"+color_emphasis, mode);
   dfa_define_highlight_rule(inline_rule("`"), color_interpreted, mode);
   % dfa_define_highlight_rule(":[a-zA-Z]+:"+inline_rule("`"), color_interpreted, mode);
   dfa_define_highlight_rule(inline_rule("\|"R), "Q"+color_substitution, mode);
   dfa_define_highlight_rule(inline_rule(":"), color_directive, mode);
   dfa_define_highlight_rule(inline_rule("\*\*"R), "Q"+color_strong, mode);
   dfa_define_highlight_rule(inline_rule("``"), "Q"+color_literal, mode);

   % Literal Block marker
   dfa_define_highlight_rule("::[ \t]*$", color_literal, mode);
   % Doctest Block marker
   dfa_define_highlight_rule("^[ \t]*>>>.*", color_literal, mode);

   % Reference Marks
   %  URLs and Emails
   dfa_define_highlight_rule("(https?|ftp|file)://[^ \t>]+", color_url, mode);
   % dfa_define_highlight_rule ("[^ \t\n<]*@[^ \t\n>]+", color_email, mode);
   %  crossreferences
   dfa_define_highlight_rule("[\-a-zA-Z0-9_]*[a-zA-Z0-9]__?[^a-zA-Z0-9]"R, color_reference, mode);
   dfa_define_highlight_rule("[\-a-zA-Z0-9_]*[a-zA-Z0-9]__?$"R, color_reference, mode);
   %  reference with backticks
   dfa_define_highlight_rule("`[^`]*`__?", color_reference, mode);
   %   footnotes and citations
   dfa_define_highlight_rule("\[[a-zA-Z0-9#\*\.\-_]+\]+_"R, color_reference, mode);

   % Reference Targets
   %  inline target
   dfa_define_highlight_rule("_`[^`]+`"R, color_target, mode);
   %  named crosslinks, footnotes and citations
   dfa_define_highlight_rule("^\.\. [_\[].*"R, color_target, mode);
   % substitution definitions
   dfa_define_highlight_rule("^\.\. [|].*"R, color_target, mode);
   %  anonymous
   dfa_define_highlight_rule("^__ [^ \t]+.*$"R, color_target, mode);
   %  footnotes and citations
   dfa_define_highlight_rule("^\.\. \[[a-zA-Z#\*]+\].*"R, color_target, mode);

   % Comments
   dfa_define_highlight_rule("^\.\."R, "Pcomment", mode);

   % Directives
   dfa_define_highlight_rule("^\.\. [^ \t]+.*::"R, color_directive, mode);

   % Lists
   %  itemize
   dfa_define_highlight_rule("^[ \t]*[\-\*\+][ \t]+"R, "Q"+color_list_marker, mode);
   %  enumerate
   dfa_define_highlight_rule("^[ \t]*[0-9a-zA-Z][0-9a-zA-Z]?\.[ \t]+"R, color_list_marker, mode);
   dfa_define_highlight_rule("^[ \t]*\(?[0-9a-zA-Z][0-9]?\)[ \t]+"R, color_list_marker, mode);
   dfa_define_highlight_rule("^[ \t]*#\.[ \t]+"R, color_list_marker, mode);
   %  field list
   dfa_define_highlight_rule("^[ \t]*:.+:[ \t]+"R, "Q"+color_list_marker, mode);
   %  option list
   dfa_define_highlight_rule("^[ \t]*--?[a-zA-Z]+  +"R, color_list_marker, mode);
   %  definition list
   % doesnot work as jed's DFA regexps span only one line

   % Hrules and Sections
   % dfa_define_highlight_rule(Underline_Regexp, color_transition, mode);
   % doesnot work, as DFA regexps do not support "\( \) \1"-syntax.
   % So we have to resort to separate rules
   foreach (Underline_Chars)
       {
        $1 = ();
          $1 = str_quote_string(char($1), "\^$[]*.+?"R, '\\');
          $1 = sprintf("^%s%s+[ \t]*$", $1, $1);
        dfa_define_highlight_rule($1, color_transition, mode);
       }

   dfa_build_highlight_table(mode);
}
dfa_set_init_callback(&setup_dfa_callback, mode);
%%% DFA_CACHE_END %%%
enable_dfa_syntax_for_mode(mode);

#else
% define_syntax( '`', '"', mode);              % strings
define_syntax ("..", "", '%', mode);         % Comments
define_syntax ("[", "]", '(', mode);           % Delimiters
define_syntax ("0-9a-zA-Z", 'w', mode);        % Words
% define_syntax ("-+*=", '+', mode);           % Operators
% define_syntax ("-+0-9.", '0', mode);         % Numbers
% define_syntax (",", ',', mode);              % Delimiters
% define_syntax (";", ',', mode);              % Delimiters
#endif

% Keymap
% ======
% ::

!if (keymap_p(mode))
  make_keymap(mode);

% the backtick is is needed too often to be bound to quoted insert
definekey("self_insert_cmd", "`", mode);
% I recommend "�" but this might not be everyones favourite
% definekey("self_insert_cmd", "�", mode);
% Fallback: _Reserved_Key_Prefix+"`":
definekey_reserved("quoted_insert", "`", mode); %

% "&Layout");                                                  "l", mode);
definekey_reserved("rst->section_header",                      "ls", mode); % "&Section"
definekey_reserved("rst->block_markup(\"preformatted\")",      "lp", mode); % "P&reformatted"
definekey_reserved("rst->markup(\"emphasis\")",                "le", mode); % "&Emphasis"
definekey_reserved("rst->markup(\"strong\")",                  "ls", mode); % "&Strong"
definekey_reserved("rst->markup(\"literal\")",                 "ll", mode); % "&Literal"
definekey_reserved("rst->markup(\"subscript\")",               "lb", mode); % "Su&bscript"
definekey_reserved("rst->markup(\"superscript\")",             "lp", mode); % "Su&bscript"
definekey_reserved("rst->markup(\"hrule\")",                   "lh", mode); % "&Hrule"
definekey_reserved("comment_region_or_line\")",                "lc", mode); % "&Comment"
% "&References\")",                        %                   "", mode);
definekey_reserved("rst->markup(\"hyperlink_ref\")",           "rh", mode); % "&Reference (link)"
definekey_reserved("rst->markup(\"anonymous_hyperlink_ref\")", "ra", mode); % "&Anonymous Reference"
definekey_reserved("rst->markup(\"numeric_footnote_ref\")",    "rf", mode); % "&Footnote"
definekey_reserved("rst->markup(\"symbolic_footnote_ref\")",   "rs", mode); % "&Symbolic Footnote"
definekey_reserved("rst->markup(\"citation_ref\")",            "rc", mode); % "&Citation"
definekey_reserved("rst->markup(\"substitution_ref\")",        "rs", mode); % "&Substitution"
% "Reference &Targets\")",                  %                  "", mode);
definekey_reserved("rst->markup(\"hyperlink\")",               "tr", mode); % "&Reference (link)"
definekey_reserved("rst->markup(\"anonymous_hyperlink\")",     "ta", mode); % "&Anonymous Reference"
definekey_reserved("rst->markup(\"numeric_footnote\")",        "tf", mode); % "&Footnote"
definekey_reserved("rst->markup(\"symbolic_footnote\")",       "ts", mode); % "&Symbolic Footnote"
definekey_reserved("rst->markup(\"citation\")",                "tc", mode); % "&Citation"
definekey_reserved("rst->markup(\"directive\")",               "td", mode); % "&Directive"
definekey_reserved("rst->markup(\"substitution\")",            "ts", mode); % "&Substitution"
% "&Export\")",                            %                   "", mode);
definekey_reserved("rst_to_html",                              "eh", mode); % "&Html"
definekey_reserved("rst_to_latex",                             "el", mode); % "&Latex"
definekey_reserved("rst_to_pdf",                               "ep", mode); % "&Latex"
definekey_reserved("rst->set_export_cmd(\"html\")",            "oh", mode); % "Set H&tml Export Options"
definekey_reserved("rst->set_export_cmd(\"tex\")",             "ol", mode); % "Set Late&x Export Options"
definekey_reserved("rst->set_export_cmd(\"pdf\")",             "op", mode); % "Set Late&x Export Options"
% "&View\")",                              %                   "", mode);
definekey_reserved("rst_view_html",                            "vh", mode); % "&Html"
definekey_reserved("rst_view_latex",                           "vl", mode); % "&Latex"
definekey_reserved("rst_view_pdf",                             "vp", mode); % "&Latex"
%                                                              "", mode);
definekey_reserved("list_routines",                            "n", mode); % &Navigator"

% Mode Menu
% =========
% ::

% append a new popup to menu and return the handle
static define new_popup(menu, popup)
{
   menu_append_popup(menu, popup);
   return strcat(menu, ".", popup);
}

static define rst_menu(menu)
{
   variable popup;
   popup = new_popup(menu, "Block &Markup");
   % ^CP...  Paragraph styles, etc. (<p>, <br>, <hr>, <address>, etc.)
   menu_append_item(popup, "&Section", "rst->section_header");
   menu_append_item(popup, "P&reformatted", &block_markup, "preformatted");
   menu_append_item(popup, "&Hrule", &markup, "hrule");
   menu_append_item(popup, "&Directive", &markup, "directive");
   menu_append_item(popup, "&Comment", "comment_region_or_line");
   % ^CS...  Character styles (<em>, <strong>, <b>, <i>, etc.)
   popup = new_popup(menu, "&Inline Markup");
   menu_append_item(popup, "&Emphasis", &markup, "emphasis");
   menu_append_item(popup, "&Literal", &markup, "literal");
   menu_append_item(popup, "&Interpreted", &markup, "interpreted");
   menu_append_item(popup, "&Strong", &markup , "strong");
   menu_append_item(popup, "Su&bscript", &markup, "subscript");
   menu_append_item(popup, "Su&perscript", &markup, "superscript");
   % References (outgoing links)
   popup = new_popup(menu, "&References (outgoing links)");
   menu_append_item(popup, "&Hyperlink", &markup, "hyperlink_ref");
   menu_append_item(popup, "&Anonymous Hyperlink", &markup, "anonymous_hyperlink_ref");
   menu_append_item(popup, "Numeric &Footnote", &markup, "numeric_footnote_ref");
   menu_append_item(popup, "&Symbolic Footnote", &markup, "symbolic_footnote_ref");
   menu_append_item(popup, "&Citation", &markup, "citation_ref");
   menu_append_item(popup, "&Substitution", &markup, "substitution_ref");
   % Reference Targets
   popup = new_popup(menu, "&Targets");
   menu_append_item(popup, "&Hyperlink (URL)", &markup, "hyperlink");
   menu_append_item(popup, "&Anonymous Hyperlink", &markup, "anonymous_hyperlink");
   menu_append_item(popup, "Numeric &Footnote", &markup, "numeric_footnote");
   menu_append_item(popup, "&Symbolic Footnote", &markup, "symbolic_footnote");
   menu_append_item(popup, "&Citation", &markup, "citation");
   menu_append_item(popup, "&Substitution", &markup, "substitution");
   % Directives
   popup = new_popup(menu, "&Directives");
   menu_append_item(popup, "&Number Sections", &insert_directive, "sectnum");
   menu_append_item(popup, "Table of &Contents", &insert_directive, "contents");
   menu_append_item(popup, "Ima&ge",  &insert_directive, "image");
   menu_append_item(popup, "&Figure", &insert_directive, "figure");
   menu_append_item(popup, "T&able",  &insert_directive, "table");
   menu_append_item(popup, "&CSV Table",  &insert_directive, "csv-table");
   menu_append_item(popup, "&Title",  &insert_directive, "title");
   menu_append_item(popup, "&Include", &insert_directive, "include");
   menu_append_item(popup, "&Raw", &insert_directive, "raw");
   menu_append_separator(menu);
#ifexists list_routines
   menu_append_item(menu, "&Navigator", "list_routines");
   menu_append_separator(menu);
#endif
   % Export to a target file
   popup = new_popup(menu, "&Export");
   menu_append_item(popup, "&Html", "rst_to_html");
   menu_append_item(popup, "&Latex", "rst_to_latex");
   menu_append_item(popup, "&Pdf", "rst_to_pdf");
   % View target file
   popup = new_popup(menu, "&View");
   menu_append_item(popup, "&Html", "rst_view_html");
   menu_append_item(popup, "&Latex", "rst_view_latex");
   menu_append_item(popup, "&Pdf", "rst_view_pdf");
   % Set export command
   popup = new_popup(menu, "Set Export &Cmd");
   menu_append_item(popup, "&Html", &set_export_cmd, "html");
   menu_append_item(popup, "&Latex", &set_export_cmd, "tex");
   menu_append_item(popup, "&Pdf", &set_export_cmd, "pdf");
   % Help commands
   menu_append_separator(menu);
   popup = new_popup(menu, "&Help");
   menu_append_item(popup, "Doc &Index", "browse_url",
      path_concat(Rst_Documentation_Path, "index.html"));
   menu_append_item(popup, "&Quick Reference", "browse_url",
      path_concat(Rst_Documentation_Path, "user/rst/quickref.html"));
   menu_append_item(popup, "&Directives", "browse_url",
      path_concat(Rst_Documentation_Path, "ref/rst/directives.html"));
   menu_append_separator(popup);
   menu_append_item(popup, "Rst2&Html Help", &command_help, Rst2Html_Cmd);
   menu_append_item(popup, "Rst2&Latex Help", &command_help, Rst2Latex_Cmd);
   % Default conversion and browse
   menu_append_item(menu, "&Run Buffer", "run_buffer");
}

% Rst Mode
% ========
% 
% ::

% set the comment string
set_comment_info(mode, ".. ", "", 0);

public define rst_mode()
{
   set_mode(mode, 1);
   % indent|format with structured_text_hook from structured_text.sl
   structured_text_hook();
   use_syntax_table(mode);
   % use_keymap (mode);
   mode_set_mode_info(mode, "fold_info", "..{{{\r..}}}\r\r");
   mode_set_mode_info(mode, "init_mode_menu", &rst_menu);
   mode_set_mode_info("run_buffer_hook", &rst_to_html);
   mode_set_mode_info("dabbrev_word_chars", get_word_chars());

   % define_blocal_var("help_for_word_hook", &rst_help);
   run_mode_hooks(mode + "_mode_hook");
}
