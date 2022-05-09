#!/bin/rdmd

import std.process;
import std.string : stripRight;
import std.file : write;
import std.path : dirSeparator;

alias SEP = dirSeparator;
enum GITINFO_PATH = "src" ~ SEP ~ "gitinfo.d";

int main(string[] args) {
	final switch (args[1]) {
	case "version":
		string git_path = environment.get("GIT_PATH", "git");
		args = [ git_path, "describe", "--dirty", "--tags" ];
		
		auto git = execute(args);
		if (git.status)
			return git.status;
		
		string ver = stripRight(git.output);
		write(GITINFO_PATH,
		`// NOTE: This file was automatically generated.
		module gitinfo;
		
		enum GIT_DESCRIPTION = "`~ver~`";`);
		return 0;
	}
}