#!/usr/bin/perl -W

# Yarxi.PL - Консольный интерфейс к словарю Яркси.
#
# Оригинальная программа и база данных словаря - (c) Вадим Смоленский.
# (http://www.susi.ru/yarxi/)
#
# Copyright (C) 2007-2008  Андрей Смачёв aka Biga.
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
use Encode;
use JDCommon;

# Extract the program directory
my $dirref = $0;
$dirref =~ s/\/[^\/]*$/\//;

# Turn on autoflush
$| = 1;

# Parse parameters
my $jr_kan = $ARGV[0];
my $jr_tan = $ARGV[1];

my $lang = 'ru';

my $db_filename = ( exists($ARGV[2]) ? $ARGV[2] : 'yarxi_u.db');
#unlink $dirref."$db_filename";

my $dbi_path = "dbi:SQLite:dbname=${dirref}${db_filename}";

my $dbh = DBI->connect($dbi_path,"","");

sub snd_key {
    my ($snd) = @_;

    $snd =~ s/m([^aiueoy])/n$1/g;
    
    $snd =~ s/([aiueon])~/$1/g;
    
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

    my $sth = $dbh->prepare($sql);
    assert($sth, "");
    
    return $sth;
}

sub flush_kan {
    my ($buf_ref, $sth) = @_;
    
    foreach ( @$buf_ref ) {
        assert ( scalar(@$_) == scalar(@kan_fields), "");
        $sth->execute( @$_ );
    }
}
#----------------------------------------------------------------------

sub process_kan {
    
    print "\n == jr_kan == \n";
	
	create_kan_table();
	
    open Temp, $jr_kan;
    
    my $date = <Temp>; # The first line is date
    chomp($date);
    my $number = <Temp>; # The second line is the number of records
    chomp($number);

    my $start_time = time();

    my @buf = ();
    my $buf_max = 40;
    my $sth = prepare_kan_sth ( $buf_max );

    my $line = 0; # Line counter
    my $c = 0;    # counter
    my $c2 = 0;   # subcounter

    my $nomer = 0;
    while (my $s = <Temp>) {
        $line++;
        $s = decode_utf8($s);
        $s =~ s/\s+$//; # Trim left spaces
        
        next if ( $s eq '.' );
        
        my @arr = split('`', $s);

        my $first = shift @arr;
        my ( $strokes, $utility, $unicode, $bushu, $rusnick);
        if ( $first =~ /^(\d\d)(\d\d)(\d{5})([\d\/]*)(.*)$/ ) {
            $strokes = $1;
            $utility = $2;
            $unicode = $3;
            $bushu = $4;
            $rusnick = $5;
            
            my @bushu_spl = split('/',  $bushu);
            $bushu = '*'.join('*', @bushu_spl).'*';
        } else {
            print "\n\nSyntax wrong at line $line: first token: "
                    .encode_utf8($first)."\n\n";
            next;
        }
        
        my $onyomi      = (shift @arr or '');
        $onyomi = '*'.$onyomi if( $onyomi =~ /^[^\*]/ );
        $onyomi = $onyomi.'*' if( $onyomi =~ /[^\*]$/ );
        
        my $kunyomi     = (shift @arr or '');
        my $russian     = (shift @arr or '');
        my $compounds   = (shift @arr or '');
        my $dicts       = (shift @arr or '');
        my $concise     = (shift @arr or '');
        
        if ( $compounds =~ s/^_([^_]*)_// ) { # Переносится в начало кунъёми
            $kunyomi = $1.$kunyomi;
        }
        if ( $compounds =~ s/^_([^_]*)_// ) { # Если повторяется, то переносится в конец кунъёми.
            $kunyomi .= $1;
        }
        
        $nomer++;
        
        # Store to buffer
        push @buf, [
                $nomer,
                encode_utf8($strokes),
                encode_utf8($utility),
                encode_utf8($unicode), 
                encode_utf8($bushu),
                encode_utf8($rusnick),
                encode_utf8($onyomi), 
                encode_utf8($kunyomi),
                encode_utf8($russian),
                encode_utf8($compounds),
                encode_utf8($dicts),
                encode_utf8($concise),
            ];
        
        if ( @buf == $buf_max ) {
        # Flush the buffer
            assert ( scalar(@buf) == $buf_max, "" );
            flush_kan(\@buf, $sth);
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
    close Temp;
    
    # Flush the rest
    if ( @buf ) {
        $sth = prepare_kan_sth( scalar(@buf) / scalar(@kan_fields) );
        flush_kan(\@buf, $sth);
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

    my $sth = $dbh->prepare($sql);
    assert($sth, "");
    
    return $sth;
}

sub flush_tan {
    my ($buf_ref, $sth) = @_;
    
    foreach ( @$buf_ref ) {
        assert ( scalar(@$_) == scalar(@tan_fields), "");
        $sth->execute( @$_ );
    }
}
#----------------------------------------------------------------------

sub process_tan {
    
    print "\n == jr_tan == \n";
	
	create_tan_table();
	
    open Temp, $jr_tan;
    
    my $date = <Temp>; # The first line is date
    chomp($date);
    my $number = <Temp>; # The second line is the number of records
    chomp($number);

    my $start_time = time();

    my @buf = ();
    my $buf_max = 40;
    my $sth = prepare_tan_sth ( $buf_max );

    my $line = 0; # Line counter
    my $c = 0;    # counter
    my $c2 = 0;   # subcounter

    my $nomer = 0;
    while (my $s = <Temp>) {
        $line++;
        $s = decode_utf8($s);
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
            print "\nTan: Syntax wrong at line $line: first token: ".encode_utf8($first)."\n";
            next;
        }
        
        my $kana = (shift @arr or '');
        my $reading = (shift @arr or '');
        my $russian = (shift @arr or '');
        
        $nomer++;
        
        # Store to buffer
        push @buf, [
                $nomer,
                encode_utf8($k[0]),
                encode_utf8($k[1]),
                encode_utf8($k[2]),
                encode_utf8($k[3]),
                encode_utf8($kana),
                encode_utf8($reading),
                encode_utf8($russian)
            ];
        
        if ( @buf == $buf_max ) {
        # Flush the buffer
            assert ( scalar(@buf) == $buf_max, "" );
            flush_tan(\@buf, $sth);
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
    close Temp;

    # Flush the rest
    if ( @buf ) {
        $sth = prepare_tan_sth( scalar(@buf) / scalar(@tan_fields) );
        flush_tan(\@buf, $sth);
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
