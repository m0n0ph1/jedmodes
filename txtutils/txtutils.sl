% txtutils.sl
% Tools for text processing (marking, string processing, formatting)
% 
% Copyright (c) 2005 G�nter Milde
% Released under the terms of the GNU General Public License (ver. 2 or later)
%
% VERSIONS
%  2.0              * get_word(), bget_word() now "region aware"
%                   * new functions mark_line(), get_line(), autoinsert()
%                   * bugfix for indent_region_or_line() (used to leave stuff
%                     on stack)
%  2.1       	    * mark_word(), bmark_word() test for buffer local variable
%                    "Word_Chars" (using get_blocal from sl_utils.sl)
%  2.2   2003-11    * removed indent_region_or_line() (now in cuamisc.sl)
%                   * changed mark_/get_word: added 2nd opt arg skip
%                               -1 skip backward, if not in a word
%                                0 don't skip
%                                1 skip forward, if not in a word
%                    Attention: get_word now returns last word, if the point is
%                    just behind a word (that is the normal way jed treats 
%                    word boundaries)
%  2.3   2004-11-24 * New function insert_markup(beg_tag, end_tag)
%  2.3.1 2005-05-26  bugfix: missing autoload (report PB)
%  2.3.2 2005-06-09 * reintroduced indent_region_or_line() 
%  	 	      jed99-17's cuamisc.sl doesnot have it
%  2.3.3 2005-10-14 * added documentation
%  2.3.3 2005-11-21 * removed "public" from definitions of functions 
%                     returning a value
%  2.4   2005-11-24 * new function local_word_chars() that also probes
%  	 	      mode_get_mode_info("word_chars")
%  	 	      new (optional) arg 'lines' for get_buffer()


% _debug_info = 1;

% --- Requirements ---

autoload("get_blocal", "sl_utils");
autoload("push_defaults", "sl_utils");

%--- marking and regions ---------------------------------------------

%!%+
%\function{local_word_chars}
%\synopsis{Return the locally valid set of word chars}
%\usage{String local_word_chars()}
%\description
%  Returns the currently defined set of characters that constitute a word in
%  the local context: (in order of preference)
% 
%    * the buffer local variable "Word_Chars"
%    * the mode-info field "word_chars" (with \var{mode_get_mode_info})
%    * the global definition (with \var{get_word_chars}).
%\example
%  Define a global set of word_chars with e.g.
%#v+
%  define_word("a-zA-Z")
%#v-
%  Define a mode-specific set of word_chars with e.g.
%#v+
%  mode_set_mode_info("word_chars", "a-zA-Z")
%#v-
%  Define a buffer-specific set of word_chars with e.g.
%#v+
%  define_blocal_var("word_chars", "a-zA-Z")
%#v-
%\seealso{}
%!%-
define local_word_chars()
{
   variable word_chars = get_blocal("Word_Chars");
   if (word_chars != NULL)
     return word_chars;
   word_chars = mode_get_mode_info("word_chars");
   if (word_chars != NULL)
     return word_chars;
   return get_word_chars();
}
  

%!%+
%\function{mark_word}
%\synopsis{Mark a word}
%\usage{ mark_word(word_chars=local_word_chars(), skip=0)}
%\description
% Mark a word as visible region.  Get the idea of the characters
% a word is made of from the optional argument \var{word_chars}
% or  \var{local_word_chars}.  The optional argument \var{skip} tells how to
% skip non-word characters:
% 
%   -1 skip backward
%    0 don't skip (default)
%    1 skip forward
%    
%\seealso{mark_line, get_word, define_word, define_blocal_var, push_visible_mark}
%!%-
public define mark_word() % (word_chars=local_word_chars(), skip=0)
{
   variable word_chars, skip;
   (word_chars, skip) = push_defaults( , 0, _NARGS);
   if (word_chars == NULL)
     word_chars = local_word_chars();
   switch (skip)
     { case -1: skip_chars(word_chars);
	bskip_chars("^"+word_chars); 
     }
     { case  1: skip_chars("^"+word_chars);
	if(eolp()) return push_visible_mark();
     }
   % Find word boundaries
   bskip_chars(word_chars);
   push_visible_mark();
   skip_chars(word_chars);
}

% % mark a word (skip forward if between two words)
% public define fmark_word() % fmark_word(word_chars=local_word_chars())
% {
%    variable args = __pop_args (_NARGS);
%    mark_word(__push_args(args), 1);
% }

% % mark a word (skip backward if not in a word)
% public define bmark_word () % (word_chars=local_word_chars())
% {
%    variable args = __pop_args (_NARGS);
%    mark_word(__push_args(args), -1);
% }


%!%+
%\function{get_word}
%\synopsis{Return the word at point as string}
%\usage{String get_word(word_chars=local_word_chars(), skip=0)}
%\description
%  Return the word at point (or a visible region) as string.
%  
%  See \var{mark_word} for the "word finding algorithm"
%  and meaning of the optional arguments.
%\seealso{bget_word, mark_word, define_word, push_visible_mark}
%!%-
define get_word() % (word_chars=local_word_chars(), skip=0)
{
   % pass on optional arguments
   variable args = __pop_args(_NARGS);
   push_spot;
   !if (is_visible_mark)
     mark_word (__push_args(args));
   bufsubstr();
   pop_spot();
}

% % return the word at point as string (skip forward if between two words)
% public define fget_word() %  (word_chars=local_word_chars())
% {
%    variable word_chars = push_defaults( , _NARGS);
%    get_word(word_chars(args), 1);
% }


%!%+
%\function{bget_word}
%\synopsis{Return the word at point as string, skip back if not in a word}
%\usage{String get_word([String word_chars], skip=0)}
%\description
%  Return the word at point (or a visible region) as string.
%  Skip back over non-word characters when not in a word.
%  This is a shorthand for get_word(-1).
%  See \var{mark_word} for the "word finding algorithm"
%\seealso{get_word, mark_word, define_word}
%!%-
define bget_word() % (word_chars=local_word_chars())
{
   variable word_chars = push_defaults( , _NARGS);
   get_word(word_chars, -1);
}


%!%+
%\function{mark_line}
%\synopsis{Mark the current line}
%\usage{mark_line()}
%\description
%  Mark the current line as an invisible region
%\seealso{push_mark_eol}
%!%-
public define mark_line()
{
   bol();
   push_mark_eol();
}

%!%+
%\function{get_line}
%\synopsis{Return the current line as string}
%\usage{String get_line()}
%\description
%  Return the current line as string. In contrast to the standard 
%  \var{line_as_string}, this keeps the point at place.
%\seealso{line_as_string, mark_line, bufsubstr}
%!%-
define get_line()
{
   push_spot();
   line_as_string();  % leave return value on stack
   pop_spot();
}


%!%+
%\function{get_buffer}
%\synopsis{Return buffer as string}
%\usage{String get_buffer(kill=0, lines=0)}
%\description
%  Return buffer as string. 
%  If a visible region is defined, return it instead.
%  If \var{kill} is not zero, the buffer/region will be deleted in the process.
%  If \var{lines} is not zero, whole lines will be returned
%\seealso{bufsubstr, push_visible_mark}
%!%-
define get_buffer() % (kill=0, lines=0)
{
   variable  kill, lines;
   (kill, lines) = push_defaults(0, 0, _NARGS);

   push_spot();
   !if(is_visible_mark())
     mark_buffer();
   else if (lines)
     {
	check_region(0);
	eol(); 
	go_right_1();
	exchange_point_and_mark();
	bol();
     }
   
   if (kill)
     bufsubstr_delete(); % leave return value on stack
   else
     bufsubstr(); % leave return value on stack
   pop_spot();
   return; % (str)
}

% --- formatting -----------------------------------------------------

%!%+
%\function{indent_buffer}
%\synopsis{Format a buffer with \var{indent_line}}
%\usage{indent_buffer()}
%\description
%  Call \var{indent_line} for all lines of a buffer.
%\seealso{indent_line, indent_region_or_line}
%!%-
public define indent_buffer()
{
   push_spot;
   bob;
   do
     indent_line;
   while (down_1);
   pop_spot;
}

%!%+
%\function{number_lines}
%\synopsis{Number buffer lines}
%\usage{number_lines()}
%\description
%  Precede all lines in the buffer or a visible region with line numbers
%\notes
%  The numbers are not just shown, but actually inserted into the buffer.  
%  Use \var{toggle_line_number_mode} (Buffers>Toggle>Line_Numbers) to show
%  line numbers without inserting them in the buffer.
%\seealso{set_line_number_mode, toggle_line_number_mode}
%!%-
public define number_lines ()
{
   variable visible_mark = is_visible_mark();
   push_spot;
   if(visible_mark)
     narrow;
   eob;
   variable i = 1,
     format = "%"+string(strlen(string(what_line())))+"d ";
   bob;
   do
     { bol;
        insert(sprintf(format, i));
	i++;
     }
   while (down_1);
   if (visible_mark)
     widen;
   pop_spot;
}

%!%+
%\function{autoinsert}
%\synopsis{Auto insert text in a rectangle}
%\usage{autoinsert()}
%\description
% Insert the content of the first line into a rectangle defined by 
% point and mark. This is soewhat similar to \var{open_rect} but for 
% arbitrary content.
% 
% If you have to fill out collumns with identical content, write the content
% in the first line, then mark the collumn and call \var{autoinsert}.
%\seealso{open_rect}
%!%-
public define autoinsert()
{
   () = dupmark();
   narrow;
   % get string to insert
   check_region(0);
   variable end_col = what_column();
   bob();
   goto_column(end_col);
   variable str = bufsubstr();
   variable beg_col = end_col - strlen(str);
   while (down_1)
     {
	goto_column(beg_col);
        insert(str);
     }
   widen;
}

%{{{ indent_region_or_line()      % should go to a generic place (site.sl?)
%!%+
%\function{indent_region_or_line}
%\synopsis{Indent the current line or (if defined) the region}
%\usage{Void indent_region_or_line ()}
%\description
%   Call the indent_line_hook for every line in a region.
%   If no region is defined, call it for the current line.
%\seealso{indent_line, set_buffer_hook, is_visible_mark}
%!%-
public define indent_region_or_line ()
{
   !if(is_visible_mark ())
     {
	indent_line ();
	return;
     }

   check_region (1);                  % make sure the mark comes first
   variable end_line = what_line ();
   exchange_point_and_mark();         % now point is at start of region
   while (what_line() <= end_line)
     {indent_line (); go_down_1 ();}
   pop_mark (0);
   pop_spot ();
}
%}}}

%!%+
%\function{insert_markup}
%\synopsis{Insert markup around region or word}
%\usage{Void insert_markup(Str beg_tag, Str end_tag)}
%\description
%   Inserts beg_tag and end_tag around the region or current word.
%\example
%  Marking a region and 
%#v+
%   insert_markup("<b>", "</b>");
%#v-
%  will highlight the word as bold in html, while
%#v+
%   insert_markup("{\textbf{", "}");
%#v-
%  will do the same for LaTeX.
%\seealso{mark_word}
%!%-
define insert_markup(beg_tag, end_tag)
{
   !if (is_visible_mark)
     mark_word ();
   variable region = bufsubstr_delete();
   insert(beg_tag + region);
   push_spot();
   insert(end_tag);
   pop_spot();
}

% Insert markup around region and (re) indent
define insert_block_markup(beg_tag, end_tag)
{ 
   () = dupmark();
   insert_markup(beg_tag, end_tag);
   indent_region_or_line();
}

provide("txtutils");
