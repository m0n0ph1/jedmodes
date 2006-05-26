% A cua-compatible mouse mode
%
% Copyright (c) 2006 G�nter Milde
% Released under the terms of the GNU General Public License (ver. 2 or later)
%
% Version     1   1998 (published 15. 01. 03)
%             1.1 mark_word does no longer skip back to next word
%                 implemented mark_by_lines for right drag
% 2005-03-18  1.2 added some tm documentation
% 2005-07-05  1.3 added `xclip` workaround for interaction with QT applications
%                 (idea by Jaakko Saaristo)
% 2006-02-15  1.4 made auxiliary variables static
% 2006-05-26  1.4.1 added missing autoload (J. Sommer)
%
% What does it do:
%
% In the Text:
%
% Left click:
%    - no region defined: move point to mouse-cursor (mouse_goto_position)
%    - outside a region: undefine region
%    - inside a region: copy to selection and delete region ("pick")
%        + Shift:   copy to (yp)-yankbuffer
%
% Middle click:
%    - insert selection at mouse-cursor
%   Shift:
%      insert (yp)-yankbuffer (yank_from_jed)
%
% Right click:
%    - region defined: extend region to mouse-cursor (ggf exchange_point_and_mark first)
%    - no region defined: move point to mouse-cursor
%
% Left drag:
%    - define a region and copy to selection
% Middle drag:
%    - insert selection at mouse-point instead of point
% Right drag:
%    - mark by lines (or, as original left drag: mark but leave point)
%
% Statusline:
%
% Left click:
%    - next buffer (jed default)
% Right click:
%    - split window (jed default)
% TODO:
% Left drag: enlarge/shrink window
%
%----------------------------------------------------------------------------

%!%+
%\variable{CuaMouse_Use_Xclip}
%\synopsis{Use `xclip` instead of x_copy_region_to_selection()}
%\usage{Int_Type CuaMouse_Use_Xclip = 0}
%\description
%  Currently, a xjed selection doesnot paste into applications using the
%  QT toolkit (all KDE applications including Klipper, lyx-qt).
%
%  This workaround uses the command line tool `xclip` to copy the selected
%  text to the X selection to overcome this problem. As it introduces a
%  dependency on `xclip` and some overhead, it is disabled by default.
%\seealso{copy_region_to_clipboard, x_copy_region_to_selection}
%!%-
custom_variable("CuaMouse_Use_Xclip", 0);

require ("mouse");
autoload("run_function", "sl_utils");
autoload("cua_mark", "cuamark");

static variable CuaMouse_Drag_Mode = 0;     % 0 no previous drag, 1 drag
static variable CuaMouse_Return_Value = 1;  % return value for the mouse_hooks
  % -1 Event not handled, pass to default hook.
  %  0 Event handled, return active window prior to event
  %  1 Event handled, stay in current window.
static variable CuaMouse_Clipboard = "";    % string where a mouse-drag is stored

%!%+
%\function{click_in_region}
%\synopsis{determine whether the mouse_click is in a region}
%\usage{Int click_in_region(col, line)}
%\description
%   Given the mouse click coordinates (col, line), the function
%   returns an Integer denoting:
%          -1 - click "before" region
%          -2 - click "after" region
%          -3 - click in region but "void space" (i.e. past eol)
%           0 - no region defined
%           1 - click in region
%\seealso{cuamouse_mark_word}
%!%-
define click_in_region(col,line)
{
   !if(is_visible_mark())
     return 0;
   check_region(0);                  % determine region boundries
   variable End_Line = what_line;
   variable End_Col = what_column;
   exchange_point_and_mark();
   variable Begin_Line = what_line;
   variable Begin_Col = what_column;
   exchange_point_and_mark();
   % click before the region?
   if((line < Begin_Line)  or ((line == Begin_Line) and (col <= Begin_Col)))
     return -1;
   % click after the region?
   if((line > End_Line) or ((line == End_Line) and (col >= End_Col)))
	return -2;
   % click in void space of region (past eol)?
   push_spot;
   goto_line (line);
   $1 = col - goto_column_best_try (col);
   pop_spot;
   if ($1)
     return -3;
   return 1;
}

define cuamouse_mark_word()
{
   variable word_chars = get_word_chars();
   if (blocal_var_exists("Word_Chars"))
       word_chars = get_blocal_var("Word_Chars");
   bskip_chars(word_chars);
   push_visible_mark();
   skip_chars(word_chars);
}

% copy region to system and internal clipboards (The region stays marked)
%!%+
%\function{copy_region_to_clipboard}
%\synopsis{Copy region to x-selection/cutbuffer and internal mouse clipboard}
%\usage{ copy_region_to_clipboard()}
%\description
%   Copy region to selection/cutbuffer and internal mouse clipboard.
%
%   The region stays marked.
%\notes
%   Tries x_copy_region_to_selection() and x_copy_region_to_cutbuffer()
%   (in this order).
%
%   With CuaMouse_Use_Xclip = 1, the region is piped to the `xclip` command
%   line tool instead. This is a workaround for interaction with applications
%   using the QT toolkit that refuse to paste the selected text otherwise.
%\seealso{CuaMouse_Use_Xclip, copy_region, yp_copy_region_as_kill}
%!%-
public define copy_region_to_clipboard()
{
   () = dupmark();
   if (bufsubstr() == "")           % no copy if the region is nil
     return;
   () = dupmark();
   if (CuaMouse_Use_Xclip)
     pipe_region("xclip");
   else
     !if (run_function("x_copy_region_to_selection"))
       () = run_function("x_copy_region_to_cutbuffer");
   () = dupmark();
   CuaMouse_Clipboard = bufsubstr ();
}

% inserts selection (or, if (from_jed == 1), CuaMouse_Clipboard) at point
define cuamouse_insert(from_jed)
{
   if (from_jed)
     insert(CuaMouse_Clipboard);
   else
     {
   !if (run_function("x_insert_selection"))
     () = run_function("x_insert_cutbuffer");
     }
}

% cursor follows mouse, warp if pointer is outside window.
define cuamouse_drag (col, line)
{
   variable top, bot;
   variable y;

   mouse_goto_position (col, line);

   top = window_info ('t');
   bot = top + window_info('r');

   (,y, ) = mouse_get_event_info();

   if ((y < top) or (y > bot))
     x_warp_pointer ();
}

define cuamouse_2click_hook(line, col, but, shift) %mark word
{
   if (but == 1)
     {
	mouse_goto_position(col, line);
	cuamouse_mark_word();
	copy_region_to_clipboard(); % only if non-empty
	return 1;
     }
   return -1;
}

% button specific down hooks
define cuamouse_left_down_hook(line, col, shift)
{
   variable click_position = click_in_region(col,line);
%    if (click_position == -3)             % click in region but void space
%      return;
   if (click_position == 1)
     {
   	copy_region_to_clipboard;
   	del_region;
% 	CuaMouse_Return_Value = 0;          % return to prev window
% 	return ();
     }
   else if (is_visible_mark())           % undefine region if existent
     {
	pop_mark(0);
     }
   mouse_goto_position (col, line);
   CuaMouse_Return_Value = 1;                 % stay in current window
}

define	cuamouse_middle_down_hook(line, col, shift)
{
   if (is_visible_mark())           % undefine region if existent
     {
	pop_mark(0);
     }
   mouse_goto_position (col, line);
   cuamouse_insert (shift);     % shift == 1: insert jed-clipboard
   CuaMouse_Return_Value = 1;   % stay in current window
}

define	cuamouse_right_down_hook(line, col, shift)
{
   if (click_in_region(col, line) == -1)  % click "before" region
     exchange_point_and_mark();
   mouse_goto_position (col, line);
   CuaMouse_Return_Value = 1;                 % stay in current window
}

% Button specific drag hooks
% argument bme: Begin_Middle_End of drag: 0 Begin, 1 Middle, 2 End (up)

% mark region
define	cuamouse_left_drag_hook(line, col, bme, shift)
{
   if (bme == 0)
     cua_mark();
   cuamouse_drag (col, line); % cursor follows mouse
   if (bme == 2) % last drag  (button up)
     copy_region_to_clipboard();
}

define	cuamouse_middle_drag_hook(line, col, bme, shift)
{
}

% mark region by lines
define	cuamouse_right_drag_hook(line, col, bme, shift)
{
   if (bme == 0)    % first drag
     {
	pop_mark_0();
	bol();
	cua_mark();
     }
   cuamouse_drag (col, line);
   eol();
   if (bme == 2) % last drag  (button up)
     copy_region_to_clipboard();
}

%generic down hook: calls the button specific ones
define cuamouse_down_hook (line, col, but, shift)
{
   if (but == 1)
     cuamouse_left_down_hook(line, col, shift);
   if (but == 2)
     cuamouse_middle_down_hook(line, col, shift);
   if (but == 4)
     cuamouse_right_down_hook(line, col, shift);
   return  CuaMouse_Return_Value;
}

% generic drag hook: calls the button specific ones
% with third argument CuaMouse_Drag_Mode: 0 first drag, 1 subsequent drag
define cuamouse_drag_hook (line, col, but, shift)
{
   if (but == 1)
     cuamouse_left_drag_hook(line, col, CuaMouse_Drag_Mode, shift);
   if (but == 2)
     cuamouse_middle_drag_hook(line, col, CuaMouse_Drag_Mode, shift);
   if (but == 4)
     cuamouse_right_drag_hook(line, col, CuaMouse_Drag_Mode, shift);
   CuaMouse_Drag_Mode = 1;
   return CuaMouse_Return_Value;
}

% generic up hook: calls the button specific drag (!) hooks
% with third argument set to 2 (up = end of drag)
define cuamouse_up_hook (line, col, but, shift)
{
   !if (CuaMouse_Drag_Mode)
     return CuaMouse_Return_Value;
   if (but == 1)
     cuamouse_left_drag_hook(line, col, 2, shift);
   if (but == 2)
     cuamouse_middle_drag_hook(line, col, 2, shift);
   if (but == 4)
     cuamouse_right_drag_hook(line, col, 2, shift);
   CuaMouse_Drag_Mode = 0;
   return CuaMouse_Return_Value;
}

mouse_set_default_hook ("mouse_2click", "cuamouse_2click_hook");
mouse_set_default_hook ("mouse_down", "cuamouse_down_hook");
mouse_set_default_hook ("mouse_drag", "cuamouse_drag_hook");
mouse_set_default_hook ("mouse_up", "cuamouse_up_hook");
%mouse_set_default_hook ("mouse_status_down", "mouse_status_down_hook");
%mouse_set_default_hook ("mouse_status_up", "mouse_status_up_hook");
