#!/usr/bin/perl -W

# Yarxi.PL - Консольный интерфейс к словарю Яркси.
#
# Оригинальная программа и база данных словаря - (c) Вадим Смоленский.
# (http://www.susi.ru/yarxi/)
#
# Copyright (C) 2007-2009  Андрей Смачёв aka Biga.
#
# This program is free software: you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# version 2 as published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, see <http://www.gnu.org/licenses/>
# or write to the Free Software Foundation, Inc., 51 Franklin Street,
# Fifth Floor, Boston, MA 02110-1301, USA.
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

use strict;
use DBI;
use utf8;
use Carp;
use FindBin;

sub BEGIN {
	unshift @INC, $FindBin::Bin; # Search modules in the directory of this file
	$| = 1; # Don't buffer the output
}

use JDCommon;

#-----------------------------------------------------------------------

# Parse parameters
my $jr_kan = $ARGV[0];
my $jr_tan = $ARGV[1];

( $jr_kan && $jr_tan ) or die "Usage: $0 jr_kan.utf8 jr_tan.utf8\n";

my $db_filename = ( exists($ARGV[2]) ? $ARGV[2] : 'yarxi_u.db');

my $dbi_path = "dbi:SQLite:dbname=${FindBin::Bin}/${db_filename}";

my $dbh = DBI->connect($dbi_path,"","");

#-----------------------------------------------------------------------

# Not used yet
sub snd_key {
	my ($snd) = @_;

	$snd =~ s/m([^aiueoy])/n$1/g;
	
	$snd =~ s/([aiueon])[:~]/$1/g;
	
	$snd =~ s/aa/a/g;
	$snd =~ s/oo/o/g;
	$snd =~ s/ou/o/g;
	
	$snd =~ s/ou/o/g;
	
	$snd =~ s/uu/u/g;
	
	$snd =~ s/ee/u/g;
	$snd =~ s/ii/i/g;
	$snd =~ s/iy/y/g;
		
	$snd =~ s/tt/t/g;
	$snd =~ s/dd/d/g;
	$snd =~ s/ss/s/g;
	$snd =~ s/zz/z/g;
	$snd =~ s/jj/j/g;
	$snd =~ s/kk/k/g;
	$snd =~ s/nn/n/g;
	$snd =~ s/nm/m/g;
	$snd =~ s/pp/p/g;
	$snd =~ s/ff/f/g;
	
	$snd =~ s/tch/ch/g;
	
	return $snd;
}
#----------------------------------------------------------------------

my @kan_fields = qw ( Nomer Str Utility Uncd Bushu RusNick Onyomi Kunyomi
		Russian Compounds Dicts Concise );
		
#----------------------------------------------------------------------

sub create_kan_table {
	
	$dbh->do ("DROP TABLE IF EXISTS Kanji");
	
	my $sql_create = <<EOT;
CREATE TABLE Kanji (
	Nomer INTEGER PRIMARY KEY NOT NULL,
	Str integer NOT NULL DEFAULT 0,
	Utility integer NOT NULL DEFAULT 0,
	Uncd integer NOT NULL,
	Bushu varchar(1) NOT NULL,
	RusNick varchar(1) NOT NULL,
	Onyomi varchar(1) NOT NULL,
	Kunyomi varchar(1) NOT NULL,
	Russian varchar(1) NOT NULL,
	Compounds varchar(1) NOT NULL,
	Dicts varchar(1) NOT NULL,
	Concise varchar(1) NOT NULL
	);
EOT
	$dbh->do( $sql_create );
}
#----------------------------------------------------------------------

sub create_kan_indices {
	$dbh->do ("CREATE INDEX UNCD_IDX ON Kanji(Uncd)" );
}
#----------------------------------------------------------------------

sub prepare_kan_sth {
	my ($N) = @_;
	
	my $sql_pv = "(?" . ( ", ?" x (@kan_fields - 1) ) . ")";

	my $sql = "INSERT INTO Kanji (".( join ", ", @kan_fields ).")"
			." VALUES ".$sql_pv.";";

	my $sth = $dbh->prepare($sql)
		or die;
	
	return $sth;
}

sub insert_kan {
	my ($buf_ref, $sth) = @_;
	
	foreach ( @$buf_ref ) {
		( scalar(@$_) == scalar(@kan_fields) ) or die;
		$sth->execute( @$_ );
	}
}
#----------------------------------------------------------------------

# Read jr_kan.utf8 and add its contents to the database.
sub process_kan {
	
	print "\n == jr_kan == \n";

	system("wc -l '$jr_kan'");
	
	create_kan_table();

	my $fh;
	open $fh, $jr_kan;
	
	my $date = <$fh>; # The first line is date
	chomp($date);
	my $number = <$fh>; # The second line is the number of records
	chomp($number);

	my $start_time = time(); # Just to print some perfomance statistics

	my @buf = ();
	my $buf_max = 40; # Add $buf_max lines in one query
	my $sth = prepare_kan_sth ( $buf_max ); # Prepare db query

	my $c = 0;  # counter
	my $c2 = 0; # subcounter

	my $nomer = 0;
	while (my $s = <$fh>) {
		chomp $s;
		utf8::decode($s);
		$s =~ s/\s+$//; # Trim left spaces
		
		next if ( $s eq '.' ); # dunno what means '.'
		
		my @arr = split('`', $s);

		my $first = shift @arr;
		my ( $strokes, $utility, $unicode, $bushu, $rusnick);
		if ( $first =~ /^(\d\d)(\d\d)(\d{5})([\d\/]*)(.*)$/ ) {
			$strokes = $1;
			$utility = $2;
			$unicode = $3;
			$bushu = $4;
			$rusnick = $5;
			
			my @bushu_spl = split('/', $bushu);
			$bushu = '*'.join('*', @bushu_spl).'*'; # It's handy to search by '*$bushu*' in such lines
		} else {
			errmsg "Syntax wrong at line $.: first token: '$first'";
			next;
		}
		
		my $onyomi = (shift @arr or '');
		# onyomi должно выглядеть как '*aaa*bbb*ccc*ddd*' для удобства поиска
		# целых онъёми, но иногда первая или последняя звёздочка отсутствует,
		# потому что для Yarxi это не важно. А мы их таки добавим.
		$onyomi = '*'.$onyomi if ( $onyomi !~ /^\*/ );
		$onyomi = $onyomi.'*' if ( $onyomi !~ /\*$/ );
		
		my $kunyomi   = (shift @arr or '');
		my $russian   = (shift @arr or '');
		my $compounds = (shift @arr or '');
		my $dicts     = (shift @arr or '');
		my $concise   = (shift @arr or '');

		# Судя по всему, в базе ограничена длина поля kunyomi, поэтому в редких
		# случаях не влезающая часть его хранится в поле compounds.
		if ( $compounds =~ s/^_([^_]*)_// ) { # Переносится в начало кунъёми
			$kunyomi = $1.$kunyomi;
		}
		if ( $compounds =~ s/^_([^_]*)_// ) { # Если повторяется, то переносится в конец кунъёми.
			$kunyomi .= $1;
		}
		
		$nomer++;

		# Строка для вставки в базу данных
		my @add = ( $nomer, $strokes, $utility, $unicode, $bushu, $rusnick,
				$onyomi, $kunyomi, $russian, $compounds, $dicts, $concise );
		
		utf8::encode($_) for @add;
		
		# Store to buffer
		push @buf, \@add;
		
		if ( @buf == $buf_max ) {
		# dump the buffer
			( scalar(@buf) == $buf_max ) or die;
			insert_kan(\@buf, $sth);
			@buf = ();
			
			$c += $buf_max;
			$c2 += $buf_max;
			print '.';
			if ( $c2 >= 1000 ) {
				print '  ' . sprintf('%7i', $nomer) . "\n";
				$c2 = 0;
			}
		}
	}
	close $fh;
	
	# save the rest
	if ( @buf ) {
		$sth = prepare_kan_sth( scalar(@buf) / scalar(@kan_fields) );
		insert_kan(\@buf, $sth);
	}
	
	create_kan_indices();
	
	# Analyze
	$dbh->do ("ANALYZE Kanji");
	
	print "\nTotal: " . sprintf('%7i', $nomer) . "\n";
	print "Time: " . (time() - $start_time) . "\n";
}
#----------------------------------------------------------------------

#======================================================================
#======================================================================

my @tan_fields = qw( Nomer K1 K2 K3 K4 Kana Reading Russian );

#----------------------------------------------------------------------

sub create_tan_table {
	my $sql_drop = "DROP TABLE IF EXISTS Tango";
	$dbh->do ($sql_drop);

	my $sql_create = <<EOT;
CREATE TABLE Tango (
	Nomer INTEGER PRIMARY KEY NOT NULL,
	K1 integer NOT NULL DEFAULT 0,
	K2 integer NOT NULL DEFAULT 0,
	K3 integer NOT NULL DEFAULT 0,
	K4 integer NOT NULL DEFAULT 0,
	Kana varchar(1) NOT NULL,
	Reading varchar(1) NOT NULL,
	Russian varchar(1) NOT NULL
	);
EOT
	$dbh->do ($sql_create);
	
}

sub create_tan_indices {
	
}

sub prepare_tan_sth {
	my ($N) = @_;

	my $sql_pv = "(?" . ( ", ?" x (@tan_fields - 1) ) . ")";

	my $sql = "INSERT INTO Tango (".( join ", ", @tan_fields ).")"
			." VALUES ".$sql_pv.";";

	my $sth = $dbh->prepare($sql) or die;
	
	return $sth;
}

sub insert_tan {
	my ($buf_ref, $sth) = @_;
	
	foreach ( @$buf_ref ) {
		( scalar(@$_) == scalar(@tan_fields) ) or die;
		$sth->execute( @$_ );
	}
}
#----------------------------------------------------------------------

sub process_tan {
	
	print "\n == jr_tan == \n";

	system("wc -l '$jr_tan'");
	
	create_tan_table();

	my $fh;
	open $fh, $jr_tan;
	
	my $date = <$fh>; # The first line is date
	chomp($date);
	my $number = <$fh>; # The second line is the number of records
	chomp($number);

	my $start_time = time();

	my @buf = ();
	my $buf_max = 40;
	my $sth = prepare_tan_sth ( $buf_max );

	my $c = 0;    # counter
	my $c2 = 0;   # subcounter

	my $nomer = 0;
	while (my $s = <$fh>) {
		chomp $s;
		utf8::decode($s);
		$s =~ s/\s+$//; # Trim left spaces
		
		next if ( $s eq '.' );
		
		my @arr = split('`', $s);

		my $first = shift @arr;
		my @k = (0,0,0,0);
		my $i = 0;
		while ( $first =~ s/^(\d{4})// ) {
			$k[$i++] = $1;
		}
		if ( $first ne '' ) {
			errmsg "Tan: Syntax wrong at line $,: first token: '$first'";
			next;
		}
		
		my $kana = (shift @arr or '');
		my $reading = (shift @arr or '');
		my $russian = (shift @arr or '');
		
		$nomer++;

		my @add = ( $nomer, @k[0..3], $kana, $reading, $russian );

		utf8::encode($_) for @add;
		
		# Store to buffer
		push @buf, \@add;
		
		if ( @buf == $buf_max ) {
		# save the buffer
			insert_tan(\@buf, $sth);
			@buf = ();
			
			$c += $buf_max;
			$c2 += $buf_max;
			print '.';
			if ( $c2 >= 1000 ) {
				print '  ' . sprintf('%7i', $nomer) . "\n";
				$c2 = 0;
			}
		}
	}
	close $fh;

	# save the rest
	if ( @buf ) {
		$sth = prepare_tan_sth( scalar(@buf) / scalar(@tan_fields) );
		insert_tan(\@buf, $sth);
	}
	
	create_tan_indices();
	
	# Analyze
	$dbh->do ("ANALYZE Tango");
	
	print "\nTotal: " . sprintf('%7i', $nomer) . "\n";
	print "Time: " . (time() - $start_time) . "\n";
}
#----------------------------------------------------------------------

# MAIN #

process_kan();
process_tan();

exit 0;
