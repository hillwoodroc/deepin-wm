//  
//  Copyright (C) 2012 Tom Beckmann, Rico Tzschichholz
// 
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
// 
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
// 
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
// 

using Clutter;
using Granite.Drawing;

namespace Gala
{
	public class WindowSwitcher : Clutter.Group
	{
		Gala.Plugin plugin;
		
		Gee.ArrayList<Clutter.Clone> window_clones = new Gee.ArrayList<Clutter.Clone> ();
		
		Meta.Window? current_window;
		
		bool active; //switcher is currently running
		
		public WindowSwitcher (Gala.Plugin _plugin)
		{
			plugin = _plugin;
		}
		
		public override bool key_release_event (Clutter.KeyEvent event)
		{
			if (((event.modifier_state & ModifierType.MOD1_MASK) == 0) || 
					event.keyval == Key.Alt_L) {
				close (event.time);
			}
			
			return true;
		}
		
		void close (uint time)
		{
			foreach (var clone in window_clones) {
				remove_child (clone);
				clone.destroy ();
			}
			
			Meta.Compositor.get_window_actors (plugin.get_screen ()).foreach ((w) => {
				var meta_win = w.get_meta_window ();
				if (!meta_win.minimized && 
					(meta_win.get_workspace () == plugin.get_screen ().get_active_workspace ()) || 
					meta_win.is_on_all_workspaces ())
					w.show ();
			});
			
			window_clones.clear ();
			
			plugin.end_modal ();
			if (current_window != null) {
				current_window.activate (time);
				current_window = null;
			}
			
			active = false;
		}
		
		public override bool captured_event (Clutter.Event event)
		{
			if (!(event.get_type () == EventType.KEY_PRESS))
				return false;
			
			var screen = plugin.get_screen ();
			var display = screen.get_display ();
			
			bool backward = (event.get_state () & X.KeyMask.ShiftMask) != 0;
			var action = display.get_keybinding_action (event.get_key_code (), event.get_state ());
			
			var prev_win = current_window;
			switch (action) {
				case Meta.KeyBindingAction.SWITCH_GROUP:
				case Meta.KeyBindingAction.SWITCH_WINDOWS:
					current_window = display.get_tab_next (Meta.TabList.NORMAL, screen, 
							screen.get_active_workspace (), current_window, backward);
					break;
				case Meta.KeyBindingAction.SWITCH_GROUP_BACKWARD:
				case Meta.KeyBindingAction.SWITCH_WINDOWS_BACKWARD:
					current_window = display.get_tab_next (Meta.TabList.NORMAL, screen, 
							screen.get_active_workspace (), current_window, true);
					break;
				default:
					break;
			}
			
			if (prev_win != current_window) {
				dim_windows ();
			}
			
			return true;
		}
		
		void dim_windows ()
		{
			var current_actor = current_window.get_compositor_private () as Actor;
			foreach (var clone in window_clones) {
				if (current_actor == clone.source) {
					clone.get_parent ().set_child_above_sibling (clone, null);
					clone.animate (Clutter.AnimationMode.EASE_OUT_QUAD, 250, depth : 0.0f, opacity : 255);
				} else {
					clone.animate (Clutter.AnimationMode.EASE_OUT_QUAD, 250, depth : -200.0f, opacity : 0);
				}
			}
		}
		
		public void handle_switch_windows (Meta.Display display, Meta.Screen screen, Meta.Window? window,
			X.Event event, Meta.KeyBinding binding)
		{
			if (active) {
				if (window_clones.size != 0)
					close (screen.get_display ().get_current_time ());
				return;
			}
			
			var metawindows = display.get_tab_list (Meta.TabList.NORMAL, screen, screen.get_active_workspace ());
			if (metawindows.length () <= 1)
				return;
			
			active = true;
			
			window_clones.clear ();
			
			foreach (var win in metawindows) {
				var actor = win.get_compositor_private () as Actor;
				var clone = new Clone (actor);
				clone.x = actor.x;
				clone.y = actor.y;
				
				add_child (clone);
				window_clones.add (clone);
			}
			
			Meta.Compositor.get_window_actors (screen).foreach ((w) => {
				var type = w.get_meta_window ().window_type;
				if (type != Meta.WindowType.DOCK && type != Meta.WindowType.DESKTOP && type != Meta.WindowType.NOTIFICATION)
					w.hide ();
			});
			
			plugin.begin_modal ();
			
			bool backward = (binding.get_name () == "switch-windows-backward");
			
			/*list windows*/
			current_window = Utils.get_next_window (screen.get_active_workspace (), backward);
			if (current_window == null)
				return;
			
			if (binding.get_mask () == 0) {
				current_window.activate (display.get_current_time ());
				return;
			}
			
			dim_windows ();
			grab_key_focus ();
		}
	}
}
