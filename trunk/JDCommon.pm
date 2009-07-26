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

use strict;
use utf8;

use Carp;

require Exporter;
@JDCommon::ISA = qw(Exporter);
# Exported symbols
push @JDCommon::EXPORT, qw(
    $dbh
    
    $term_cols $term_lines
    
    $iteration_mark
    
    &errmsg &fail &gotcha
    &kanji_from_unicode &max
    &say
    &ref_push
    &new_dom_object
    &make_dom_object &make_text_obj
    &add_child
    &arrays_equal &is_array
);

our $dbh;

our $iteration_mark = chr(0x3005); # Символ повторения иероглифа.

# Размеры терминала
our ($term_cols, $term_lines);


sub errmsg {
    my ($msg) = @_;

    utf8::encode($msg) if utf8::is_utf8($msg);
    print STDERR "\n !!! Error : $msg\n"; # ANALYSIS:
}

sub fail {
    errmsg( defined $_[0] ? $_[0] : "Без описания" );
    Carp::confess();    
}

sub gotcha ( ) {
    fail "Gotcha!"; # Для отлова хитрых ветвей кода.
}

sub kanji_from_unicode ( $ $ ) {
    my ($nomer, $unicode) = @_;
    return chr($unicode);
}

sub max ($$) {
    return ($_[1] > $_[0]) ? $_[1] : $_[0];
}

sub say ($) {
    my ($txt) = @_;
    
    utf8::encode($txt);
    
    print $txt;
}

sub ref_push ($@) { push @{$_[0] ||= []}, @_[1..$#_] }

# Data Object Model functions
 
sub new_dom_object {
    if ( @_ <= 2 ) { # Two parameters
        my ($type, $descr) = @_;
        
        my $obj = { 'type' => $type };
        $obj->{'descr'} = $descr if defined $descr;
        
        return $obj;
    }
    else {
        @_ % 2 == 1  or fail "Неверное число аргументов";
        my ($type, %init) = @_;
        $init{'type'} = $type;
        return \%init;
    }
}

# Часто используемая операция - создание объекта типа текст.
sub make_text_obj {
    my ($type, $text, %other) = @_;
    
    my $obj = \%other;
    $obj->{'type'} = $type;
    $obj->{'text'} = $text;
    
    return $obj;
}

sub add_child {
    my ($obj, @children) = @_;
    
    ref_push $obj->{'children'}, @children;
}

sub arrays_equal {
    my ($arr1, $arr2) = @_;
    
    return 0 if @$arr1 != @$arr2; # сравниваем размеры
    
    for (my $i=0; defined $arr1->[$i]; $i++) {
        return 0 if $arr1->[$i] ne $arr2->[$i];
    }
    
    return 1; # одинаковы
}

sub is_array ( $ ) { # TODO: use everywhere
    return ref($_[0]) eq 'ARRAY';
}

#----------------------------------------------------------------------
1; # Return value
