package JDCommon;

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

use utf8;
use Encode;
use Carp;

require Exporter;
@JDCommon::ISA = qw(Exporter);
# Exported symbols
push @JDCommon::EXPORT, qw(
    $dbh
    
    $term_cols $term_lines
    
    $iteration_mark
    
    &errmsg &assert &gotcha
    &kanji_from_unicode &max
    &say
    &arr_ref_push &arr_ref_push_arr
    &new_dom_object
    &make_dom_object &make_text_obj
    &add_child &add_children
    &arrays_equal
);

our $dbh;

our $iteration_mark = chr(0x3005); # Символ повторения иероглифа.

# Размеры терминала
our ($term_cols, $term_lines);


sub errmsg {
    my ($msg) = @_;

    $msg = encode_utf8($msg) if ( Encode::is_utf8($msg) );
    print STDERR "\n !!! Error : $msg\n";
}

sub assert ($$) {
    my ($bool, $msg) = @_;
    
    if ( !$bool ) {
        errmsg($msg);
        die Carp::longmess();
    }
}

sub gotcha() { # inline?
    assert( 0 , "Gotcha!"); # Для отлова хитрых ветвей кода.
}

sub kanji_from_unicode {
    my ($nomer, $unicode) = @_;
    return chr($unicode);
}

sub max ($$) {
    return ($_[1] > $_[0]) ? $_[1] : $_[0];
}

sub say {
    my ($txt) = @_;
    
    print encode_utf8($txt);
}

sub arr_ref_push {
    my ($arr_ref, $obj) = @_;
    
    return $_[0] = [$obj] if !defined($arr_ref);
    
    assert ref($arr_ref) eq 'ARRAY', "Not an ARRAY REF: ".ref($arr_ref);
    
    push @$arr_ref, $obj;
}

sub arr_ref_push_arr {
    my $to_push = $_[1];

    if ( ref($to_push) ne 'ARRAY' ) {
        errmsg("arr_ref_push_arr: pushing not array\n");
        Carp::confess();
    }

    foreach ( @$to_push ) {
        assert defined, "";
        arr_ref_push ($_[0], $_);
    }
}

# Data Object Model functions
 
sub new_dom_object {
    if ( @_ <= 2 ) { # Two parameters
        my ($type, $descr) = @_;
        
        my $tmp = {'type' => $type};
        defined $descr and $tmp->{'descr'} = $descr;
        
        return $tmp;
    } else {
        assert ( @_ % 2 == 1 , "Неверное число аргументов" ); # Нечётное число аргументов > 2
        my ($type, %init) = @_;
        $init{'type'} = $type;
        return \%init;
    }
}

# Часто используемая операция - создание объекта типа текст.
sub make_text_obj {
    my ($type, $text, %other) = @_;
    
    my $res;
    if ( %other ) {
        $res = \%other;
        $res->{'type'} = $type;
    } else {
        $res = new_dom_object ( $type );
    }
    $res->{'text'} = $text;
    
    return $res;
}

sub add_child {
    my ($obj, $child) = @_;
    
    arr_ref_push ($obj->{'children'}, $child);
}

sub add_children {
    my ($obj, $arr_ref) = @_;
    
    foreach ( @$arr_ref ) {
        next unless defined;
        add_child ($obj, $_);
    }
}

sub arrays_equal {
    my ($arr1, $arr2) = @_;
    
    return 0 if @$arr1 != @$arr2; # сравниваем размеры
    
    my $i;
    for ($i=0; defined $arr1->[$i]; $i++) {
        return 0 if $arr1->[$i] ne $arr2->[$i];
    }
    return 1;
}

#----------------------------------------------------------------------
1; # Return value
