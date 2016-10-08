% (included file)

:- doc(section, "PiLLoW bundle").

:- use_module(library(pathnames), [path_concat/3]).
:- use_module(library(write), [portray_clause/2]).
:- use_module(library(system_extra), [try_finally/3]).

pillow_base_htmldir := ~get_bundle_flag(core:pillow_base_htmldir).
pillow_base_htmlurl := ~get_bundle_flag(core:pillow_base_htmlurl).

pillow_destname := 'pillow'.

pillow_desturl := ~path_concat(~pillow_base_htmlurl, ~pillow_destname).
pillow_destdir := ~path_concat(~pillow_base_htmldir, ~pillow_destname).

% TODO: ask bundle instead
'$builder_hook'(pillow:item_prebuild_nodocs) :-
	icon_address_auto.

icon_address_auto :-
	try_finally(open(~bundle_path(core, 'library/pillow/icon_address_auto.pl'), write, OS),
	            portray_clause(OS, icon_base_address(~pillow_desturl)),
		    close(OS)).

% TODO: subtarget for installation, merge with pillow subtarget
'$builder_hook'(pillow_:item_def([
    files_from('library/pillow/images', ~pillow_destdir, [del_rec])
    ])).
