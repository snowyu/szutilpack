#!/usr/bin/perl -w
use strict;
use warnings;
use File::Find qw(find);
use Text::ParseWords qw(shellwords);
use Text::Wrap qw(wrap);

$Text::Wrap::columns = 72;

my $checkonly = grep { $_ eq '-c' } @ARGV;

# Find any ".lualocals" files that define the custom keywords
# localized in any lua files beneath that subdir.
my %custom;
find(
	{       wanted => sub {
			m#(|.*/)\.lualocals# or return;
			open(my $fh, "<", $_) or die("$_: $!");
			$custom{$1} = {
				map { $_ => 1 } shellwords(
					do { local $/; <$fh> }
				)};
		},
		no_chdir => 1
	},
	".");
keys %custom or die("no .lualocals found");

# Support locals defined by the engine.
my $lua = `which lua51 lua5.1 2>/dev/null | head -n 1`;
$lua =~ m#\S# or die("failed to find lua");
chomp($lua);
open(   my $fh, "-|", $lua, "-e", <<'EOD'
	for k, v in pairs(_G) do
		if k ~= "_G" then
			print(k)
		end
	end
	for pk, pv in pairs(package.loaded) do
		if pk ~= "_G" and _G[pk] then
			for fk, fv in pairs(pv) do
				print(pk .. "." .. fk)
			end
		end
	end
EOD
) or die($!);
my %support = map { chomp; $_ => 1 } <$fh>;
close($fh);

sub parsekeys {
	m#^\s*--\s*\Q$_[0]\E:\s+(.*)#
	  and map { $_[1]->{$_} = 1 } shellwords($1);
	1;
}

sub drawline {
	my($w, $p, $n) = ($Text::Wrap::columns, @_);
	$p ||= "";
	my $l = "-" x ($w - length($p));
	"$p$l" . ("\n" x ($n || 1));
}

sub mklocals {
	@_ or return "";
	my @x = map { my $y = $_; tr#.#_#; $y } @_;
	local $" = ", ";
	wrap("local ", "      ", "@_\n") .
	  wrap("    = ", "      ", "@x\n");
}

sub process {
	my($path, $cust) = @_;
	my %locals = (%support, %$cust);

	# Read in code, parsing out SKIP and ADD values and stripping
	# off the LUALOCALS block.
	my $orig = "";
	my $code = "";
	my %skip;
	my $inblock;
	open(my $fh, "<", $path) or die($!);
	while(<$fh>) {
		$orig .= $_;
		m#^\s*--\s*LUALOCALS\s*<# and $inblock = 1;
		$inblock
		  and parsekeys("SKIP", \%skip)
		  and parsekeys("ADD",  \%locals);
		$inblock or $code .= $_;
		m#\s*--\s*LUALOCALS\s*># and undef($inblock);
	}
	while($code =~ s#^\s*\n##) { }

	# Substitution names for 2nd-tier locals.
	my %subs = map { my $x = $_; $x =~ tr#.#_#; $_ => $x } keys %locals;

	# Strip strings and comments out from code, so we don't
	# accidentally match something inside a string literal.
	my $mcode = "";
	my($q, $b);
	for my $c (split(m##, $code)) {
		$b and(undef($b), next);
		$c eq "\\" and(($b = 1), next);
		$q ? ($c eq '"' and undef($q))
		  : ($c eq '"') ? ($q = 1)
		  :               ($mcode .= $c);
	}
	$mcode =~ s#--\[\[.*?--\]\]##g;
	$mcode =~ s#--.*$##gm;

	# Process matched from code, and include dependencies, e.g. if
	# math.floor is found, include math.
	my %matched = map { $_ => 1 }
	  grep { $mcode =~ m#\b(\Q$_\E|\Q$subs{$_}\E)\b# }
	  grep { !m#^\~# } keys %locals;
	for my $m (keys %matched) {
		my $n = $m;
		$n =~ s#\..*##;
		$matched{$n} = 1;
	}

	# Remove skip entries.
	for my $s ( (keys %skip, map { substr($_, 1) } grep { m#^\~# } keys %locals) ) {
		delete($matched{$s});
		$s =~ tr#.#_#;
		delete($matched{$s});
	}

	# Flatten results.
	my @found   = sort keys %matched;
	my @allskip = sort keys %skip;

	1 while chomp($code);
	$code .= "\n";

	if(@found or @allskip) {
		my $block = "";
		$block .= drawline("-- LUALOCALS < ");
		@allskip and $block .= wrap("-- SKIP: ", "-- SKIP: ", "@allskip\n");
		local $" = ", ";
		$block .= mklocals(grep { !m#\.# } @found);
		$block .= mklocals(grep { m#\.# } @found);
		my @unopt = grep { m#\.# and $code =~ m#\b\Q$_\E\b# } %locals;
		@unopt and warn("UNOPTIMIZED($path) = @unopt\n");
		$block .= drawline("-- LUALOCALS > ", 2);
		$code = $block . $code;
	}

	$code eq $orig and return;
	$checkonly and die("dirty: $path");

	eval {
		open(my $fh, ">", "$path.new") or die($!);
		print $fh $code;
		close($fh);
		rename("$path.new", $path);
		warn("-> $path\n");
	};
	unlink("$path.new");
	$@ and die($@);
}

my %plan;
for my $root (keys %custom) {
	find(
		{       wanted => sub {
				m#\.lua$# or return;
				my $f = $_;
				$plan{$f} = sub { process($f, $custom{$root}) }
			},
			no_chdir => 1
		},
		$root);
}
for my $k (sort keys %plan) {
	$plan{$k}->();
}
