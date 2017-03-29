%%#!/usr/bin/env escript

-module(ewc).
-export([main/1, wc/1]).

-define(BUFSIZ, 1024).

usage() ->
	io:format("usage: ewc [-clw] [file ...]~n"),
	io:format("-c\t\tcount number of bytes.~n"),
	io:format("-l\t\tcount number of lines.~n"),
	io:format("-w\t\tcount number of whitespace delimited words.~n"),
	halt(2).

main(Args) ->
	case egetopt:parse(Args, [
		{ $c, flag, count_bytes },
		{ $l, flag, count_lines },
		{ $w, flag, count_words }
	]) of
	{ok, Options, ArgsN} ->
		Opts = case length(Options) of
		0 ->
			[{count_bytes, true},{count_words, true},{count_lines,true}];
		_ ->
			Options
		end,
		process(Opts, ArgsN);
	{error, Reason, Opt} ->
		io:format("~s -~c~n", [Reason, Opt]),
		usage()
	end.

process(Opts, []) ->
	io:setopts(standard_io, [binary]),
	Counts = wc(standard_io),
	output_counts("-", Counts, Opts);
process(Opts, Files) ->
	process_files(Opts, Files).

process_files(_Opts, []) ->
	ok;
process_files(Opts, [File | Rest]) ->
	try
		Fp = open_file(File),
		Counts = wc(Fp),
		output_counts(File, Counts, Opts),
		file:close(Fp)
	catch
		throw:{error, Reason} ->
			io:format(standard_error, "ecat: ~s: ~s~n", [File, str:error(Reason)]),
			halt(1)
	end,
	process_files(Opts, Rest).

open_file("-") ->
        io:setopts(standard_io, [binary]),
	standard_io;
open_file(File) ->
	case file:open(File, [read, binary, {read_ahead, ?BUFSIZ}]) of
	{ok, Fp} ->
		Fp;
	Error ->
		throw(Error)
	end.

wc(Fp) ->
	wc(Fp, 0, 0, 0, false).
wc(Fp, Lines, Words, Bytes, IsWord) ->
	case file:read(Fp, 1) of
	eof ->
		{Lines, Words, Bytes};
	{ok, <<Octet:8>>} ->
		Nbytes = Bytes + 1,
		Nlines = if
		Octet == $\n ->
			Lines + 1;
		Octet /= $\n ->
			Lines
		end,
		{Nwords, InWord} = case {ctype:isspace(Octet), IsWord} of
		{true, _} ->
			{Words, false};
		{false, false} ->
			{Words + 1, true};
		{false, true} ->
			{Words, true}
		end,
		wc(Fp, Nlines, Nwords, Nbytes, InWord);
	Error ->
		throw(Error)
	end.

output_counts(File, {Lines, Words, Bytes}, Opts) ->
	output_count(Lines, count_lines, Opts),
	output_count(Words, count_words, Opts),
	output_count(Bytes, count_bytes, Opts),
	if
	File /= "-" ->
		io:format("~s~n", [File]);
	File == "-" ->
		io:nl()
	end.

output_count(Count, Opt, Opts) ->
	case proplists:get_value(Opt, Opts, false) of
	true ->
		io:format("~B ", [Count]);
	false ->
		ok
	end.
