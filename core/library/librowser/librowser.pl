:- module(librowser,
	[
	    update/0,
	    browse/2,
	    where/1,
	    describe/1,
	    system_lib/1,
	    apropos/1
	],[assertions, regexp]).

%% ------------------------------------------------------------

:- use_module(library(read)).
:- use_module(library(fastrw)).
:- use_module(library(system)).
:- use_module(library(streams)).
:- use_module(library(lists), [append/3]).
:- use_module(library(fuzzy_search), [damerau_lev_dist/3]).
:- use_module(library(pathnames), [path_concat/3]).

:- use_module(engine(internals), ['$bundle_id'/1]).
:- use_module(library(bundle/bundle_paths), [bundle_path/3]).
:- use_module(library(write), [writeq/1]).

%% ------------------------------------------------------------

:- data exports/3.
:- data lastm/1.

%% ------------------------------------------------------------

:- doc(author, "Angel Fernandez Pineda").
:- doc(author, "Isabel Garcia Contreras").

:- doc(title, "The Ciao library browser").
:- doc(subtitle, "A browser tool for the Ciao toplevel shell").

:- doc(summary, "@lib{librowser} was designed to provide a simple help
	facility to the user at the top level which allows
	interactively finding Ciao libraries and/or any predicates
	exported by them. It will search the default library paths
	looking for @tt{.itf} interface files. Those interface files
	are automatically generated by Ciao when compiling libraries.
	").

:- doc(module, "The @lib{librowser} library provides a set of
	predicates wich enable the user to interactively find Ciao
	libraries and/or any predicate exported by them.

        This is a simple example:

        @begin{verbatim}
?- apropos(aggregates:'.*find.*').

aggregates:findnsols/5
aggregates:findnsols/4
aggregates:findall/4
aggregates:findall/3

yes
?- 
@end{verbatim}

        @lib{librowser} is specially useful when inside GNU Emacs: just
        place the cursor over a librowser response and press C-cTAB in
        order to get help on the related predicate.  Refer to the
        @bf{\"Using Ciao inside GNU Emacs\"} chapter for further
        information.  ").

:- doc(usage,
	"It is not necesary to use this library at user programs.
         It is designed to be used at the Ciao @em{toplevel}
	 shell: @apl{ciaosh}. In order to do so, just make use of
	 @pred{use_module/1} as follows:

         @tt{use_module(library(librowser))}.

         Then, the library interface must be read. This is
         automatically done when calling any predicate at librowser,
         and the entire process will take a little moment.So, you
         should want to perform such a process after loading
         the Ciao toplevel:

         @begin{verbatim}
Ciao 0.9 #75: Fri Apr 30 19:04:24 MEST 1999
?- use_module(library(librowser)).

yes
?- update.

@end{verbatim}

        Whether you want this process to be automatically performed when
        loading @apl{ciaosh}, you may include those lines in your
        @em{.ciaorc} personal initialization file.
        ").

%% ------------------------------------------------------------
%%
%% SOME TYPES AND PROPERTIES FOR DOCUMENTATION PORPOUSES
%%
%% ------------------------------------------------------------

:- prop module_name(Module) #
	"@var{Module} is a module name (an atom)".

module_name(_).

:- prop pred_spec(Spec) #
	"@var{Spec} is a @bf{Functor/Arity} predicate
         specification".

pred_spec(_).

:- doc(apropos_spec/1,
	"Defined as:
          @includedef{apropos_spec/1}
        ").

:- prop apropos_spec(S) + regtype #
	"@var{S} is a predicate specification @tt{Pattern}, @tt{Pattern/Arity}, 
	  @tt{Module:Pattern}, @tt{Module:Pattern/Arity}.".

apropos_spec(Pattern) :-
	atm(Pattern).
apropos_spec(Pattern/Arity) :-
	atm(Pattern),
	int(Arity).
apropos_spec(Module:Pattern/Arity) :-
	atm(Pattern),
	atm(Module),
	int(Arity).
apropos_spec(Module:Pattern) :-
	atm(Pattern),
	atm(Module).

:- doc(doinclude,apropos_spec/1).

%% ------------------------------------------------------------
%%
%% READ LIBRARY INFO
%%
%% ------------------------------------------------------------

:- doc(update/0,
	"This predicate will scan the Ciao @concept{system libraries} for
	 predicate definitions. This may be done once time before
	 calling any other predicate at this library.

         update/0 will also be automatically called (once) when
         calling any other predicate at librowser.").

:- pred update #
	"Creates an internal database of modules at Ciao
	 @concept{system libraries}.".


update :-
	retractall_fact(exports(_,_,_)),
	inform_user(['Reading Ciao library info, please wait...']),
	fail.
update :-
	%ciao_lib_dir(CiaoPath),
	%( atom_concat(CiaoPath,'/lib/',Dir)
	%; atom_concat(CiaoPath,'/library/',Dir)
	%),
	bundle_src(_, Dir),
	related_files_at(Dir,Dir_itf),
	catch(extract_info_from(Dir_itf),_,true),
	fail.
update :-
	inform_user(['Browser has been loaded...']),
	nl.

update_when_needed :-
	exports(_,_,_),
	!.
update_when_needed :-
	update.

bundle_src(Bundle, Path) :-
	'$bundle_id'(Bundle),
	\+ Bundle = ciao, % (skip this one, contains several)
	bundle_path(Bundle, '.', Path).

%% ------------------------------------------------------------

related_files_at(Dir,Files) :-
	directory_files(Dir,AllFiles),
	related_files_at_aux(AllFiles,Dir,Files).

related_files_at_aux([],_,[]).
related_files_at_aux(['.'|Nf],Dir,NNf) :-
	!,
	related_files_at_aux(Nf,Dir,NNf).
related_files_at_aux(['..'|Nf],Dir,NNf) :-
	!,
	related_files_at_aux(Nf,Dir,NNf).
related_files_at_aux([File|Nf],Dir,NNf) :-
	atom_concat('.#',_,File),
	!,
	related_files_at_aux(Nf,Dir,NNf).
related_files_at_aux([File|Nf],Dir,[itf(AbsFile,Module)|NNf]) :-
	atom_concat(Module,'.itf',File),
	!,
	path_concat(Dir,File,AbsFile),
	related_files_at_aux(Nf,Dir,NNf).
related_files_at_aux([File|Nf],Dir,RelatedFiles) :-
	path_concat(Dir,File,AbsFile),
	is_dir_nolink(AbsFile),
%	file_property(AbsFile,type(directory)),
	!,
	related_files_at_aux(Nf,Dir,NNf),
	related_files_at(AbsFile, NewFiles),
	append(NNf,NewFiles,RelatedFiles).
related_files_at_aux([_|Nf],Dir,NNf) :-
	!,
	related_files_at_aux(Nf,Dir,NNf).

% TODO: copied from source_tree.pl, fix
% FileName is a directory that is not a symbolic link
is_dir_nolink(FileName) :-
	\+ file_property(FileName, linkto(_)),
	file_exists(FileName),
	file_property(FileName, type(directory)).

%% ------------------------------------------------------------

extract_info_from([]).
extract_info_from([itf(File,Mod)|Nf]) :-
	open_input(File,IO),
	inform_user(['{Reading interface info from ',Mod,'}']),
	read_exports(Mod),
	close_input(IO),
	extract_info_from(Nf).

%% ------------------------------------------------------------

read_exports(_Module) :-
        read_term(_CiaoItfSignature,[]),
        fail.
read_exports(Module) :-
	getterm(Term),
	Term = e(F,A,_,_),
	asserta_fact(exports(Module,F,A)),
	fail.
read_exports(_).

getterm(Term) :-
	( fast_read(T) -> Term = T ; Term = end_of_file ),
	( Term \== end_of_file -> true ; (!,fail) ).
getterm(Term) :-
	getterm(Term).

%% ------------------------------------------------------------
%%
%% BROWSE PREDICATE
%%
%% ------------------------------------------------------------

:- doc(browse/2,
	"This predicate is fully reversible, and is provided to
	 inspect concrete predicate specifications.
         For example:
         @begin{verbatim}
?- browse(M,findall/A).

A = 3,
M = conc_aggregates ? ;

A = 4,
M = aggregates ? ;

A = 3,
M = aggregates ? ;

no
?-
@end{verbatim}
        ").

:- pred browse(Module,Spec):
	( module_name(Module) , pred_spec(Spec) ) #
	"Asocciates the given @var{Spec} predicate specification
	 with the @var{Module} which exports it.".

browse(M,F/A) :-
	update_when_needed,
	exports(M,F,A).

%% ------------------------------------------------------------

:- doc(where/1,
	"This predicate will print at the screen the module
         needed in order to import a given predicate specification.
         For example:
@begin{verbatim}
?- where(findall/A).
findall/3 exported at module conc_aggregates
findall/4 exported at module aggregates
findall/3 exported at module aggregates

yes
?-
@end{verbatim}
        ").

:- pred where(Spec): pred_spec #
	"Display what module to load in order to import
	 the given @var{Spec}.".

where(F/A) :-
	exports(Module,F,A),
	inform_user([F,'/',A,' exported at module ',Module]),
	fail.

where(_).

%% ------------------------------------------------------------

:- doc(system_lib/1,
	"It retrieves on backtracking all Ciao system libraries stored in
         the internal database. Certainly,
	 those which were scanned at @pred{update/0} calling.
        ").

:- pred system_lib(Module) : module_name #
	"@var{Module} variable will be successively instantiated
         to the system libaries stored in the internal database.".

system_lib(Module) :-
	update_when_needed,
	exports(Module,_,_).

%% ------------------------------------------------------------

:- doc(describe/1,
	"This one is used to find out which predicates were exported
         by a given module. Very usefull when you know the library,
         but not the concrete predicate. For example:
@begin{verbatim}
?- describe(librowser).
Predicates at library librowser :

apropos/1
system_lib/1
describe/1
where/1
browse/2
update/0

yes
?-
@end{verbatim}
        ").

:- pred describe(Module) : module_name #
	"Display a list of exported predicates at the given @var{Module}".

describe(Module) :-
	update_when_needed,
	atom(Module),
	inform_user(['Predicates at library ',Module,' : ']),
	nl,
	exports(Module,F,A),
	inform_user([F,'/',A,' ']),
	fail.
describe(_).

%% ------------------------------------------------------------

:- doc(apropos/1,
	"This tool makes use of @concept{regular expresions} in order
	 to find predicate specifications. It is very usefull whether
         you can't remember the full name of a predicate.
         Regular expresions take the same format as described in
         library @lib{patterns}. Example:
@begin{verbatim}
?- apropos('write.').

write:writeq/1
write:writeq/2

yes
?- apropos('write.*'/2).

dht_misc:write_pr/2
profiler_auto_conf:write_cc_assertions/2
mtree:write_mforest/2
transaction_concurrency:write_lock/2
transaction_logging:write/2
provrml_io:write_vrml_file/2
provrml_io:write_terms_file/2
unittest_base:write_data/2
write:write_canonical/2
write:writeq/2
write:write/2
write:write_term/2
strings:write_string/2
res_exectime_hlm_gen:write_hlm_indep_each/2
res_exectime_hlm_gen:write_hlm_indep_2/2
res_exectime_hlm_gen:write_hlm_dep/2
oracle_calibration:write_conf/2
bshare_utils:write_string/2
bshare_utils:write_string_list/2
bshare_utils:write_length/2
bshare_utils:write_neg_db_stream/2
bshare_utils:write_neg_db/2
bshare_utils:write_pos_db/2

yes
@end{verbatim}
	When no predicates are found with the exact search, 
	this predicate will perform a fuzzy search which will find
        predicates at a distance of one edit, swap, 
	deletion or insertion.

@begin{verbatim}
?- apropos('wirte').
Predicate wirte not found. Similar predicates:

transaction_logging:write/2
write:write/1
write:write/2

yes
?- apropos(apend).
Predicate apend not found. Similar predicates:

hprolog:append/2
lists:append/3
llists:append/2

yes
?- 

@end{verbatim}

").

:- pred apropos(RegSpec): apropos_spec #
	"This will search any predicate specification @var{Spec} which
	 matches the given @var{RegSpec} incomplete predicate specification.".

apropos(_) :-
	update_when_needed,
	fail.

apropos(Module:Root) :-
	atom(Module),
	atom(Root),
	!,
	apropos(Module:Root/_).
apropos(Module:Root/A) :-
	atom(Module),
	atom(Root),
	set_fact(lastm('$nothing$')),
	!,
	apropos_aux(Module,Root,A).
apropos(Root) :-
	atom(Root),
	!,
	apropos(Root/_).
apropos(Root/Arity) :-
	atom(Root),
	set_fact(lastm('$nothing$')),
	!,
	apropos_aux(_,Root,Arity).

apropos_aux(Module,Root,A) :-
	atom_codes(Root,RootCodes),
	exports(Module,F,A),
	atom_codes(F,FCodes),
	match_posix(RootCodes,FCodes),
	display_pred(Module,F,A),
	fail.
apropos_aux(Module,Root,A) :-
	lastm('$nothing$'),
	display('Predicate '),
	writeq(Root), 
	display(' not found. Similar predicates:'),
	nl,
	apropos_fuzzy(Module,Root,A).
apropos_aux(_,_,_) :- nl.

apropos_fuzzy(Module,Root,A) :-
	exports(Module,F,A),
	damerau_lev_dist(Root, F, D),
	D = 1,
	display_pred(Module, F,A),
	fail.
apropos_fuzzy(_,_, _) :-
	lastm('$nothing$'),
	display('No similar predicates found').

display_pred(Module, F, A) :-
	set_fact(lastm(Module)),
	nl,
	writeq(Module:F/A).


%apropos_fuzzy(Root, _) :-
%	nl,
%	exports(Root, _, _),
%	nl,
%	nl,
%	display('NOTE: '),
%	display(Root),
%	display(' is a module'),
%	nl.
