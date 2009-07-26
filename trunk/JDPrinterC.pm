package JDPrinterC;

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
use JDCommon;
use JD_AText;

require Exporter;
@JDPrinterC::ISA = qw(Exporter);
# Exported symbols
push @JDPrinterC::EXPORT, qw(    
   
    &print_article
    &colors_table
    
    &print_object
);

# Данные
my $dom;

# Хитрый символ, который выглядит как пробел, но не пробел.
# Используется как неразрывный (непереносимый) пробел.
my $nbsp = 160;

# цветовые коды
# \033[
#  0 - цвет по умолчанию
#  4 - underline
#  5 - blink
#  7 - inverse
# 31 - dark red
# ... dark colors
# 37 - gray
# 38 - bright red
# 41-48 - dark backgrounds
# 90 - dark gray
# 91-96 - bright colors
#100-106 - bright bg

# man console_codes
my %console_codes = (
    'no'            => "[0",
    'black'         => "[30",
    'dark_red'      => "[31",
    'dark_green'    => "[32",
    'dark_brown'    => "[33",
    'dark_blue'     => "[34",
    'dark_magenta'  => "[35",
    'dark_cyan'     => "[36",
    'light_gray'    => "[37",
    'light_red'     => "[38",
    'dark_gray'     => "[90",
    'pale_red'      => "[91",
    'light_green'   => "[92",
    'light_yellow'  => "[93",
    'light_blue'    => "[94",
    'light_magenta' => "[95",
    'light_cyan'    => "[96",
);

sub console_code {
    my ($name) = @_;
    
    defined $console_codes{$name} or fail "Wrong color code name: '$name'";
    
    return "\033".$console_codes{$name}."m";
}

my %pale_map = (
        'no'            => 'light_gray',
        'dark_cyan'     => 'dark_gray',
        'light_gray'    => 'dark_gray',
        'light_red'     => 'dark_red',
        'pale_red'      => 'dark_red',
        'light_green'   => 'dark_green',
        'light_yellow'  => 'dark_brown',
        'light_blue'    => 'dark_blue',
        'light_magenta' => 'dark_magenta',
        'light_cyan'    => 'dark_cyan',
    );

my %new_pale_map;
foreach ( keys %pale_map ) {
    $new_pale_map{console_code($_)} = console_code($pale_map{$_});
}
%pale_map = %new_pale_map;

my $nocolor = console_code('no');
#my $underline = "\033[4m";
#my $bg_black = "\033[40m";
#my $bg_red = "\033[41m";

# Встроенная "тёмная" схема
my %colors = (
        'bold'          => 'light_green',
        'comment'       => 'light_blue',
        'example'       => 'pale_red',
        'fd'            => 'light_gray',
        'footer'        => 'light_gray',
        'kun'           => 'light_cyan',
        'kun_ref'       => 'no',
        'kokuji'        => 'light_red',
        'lat'           => 'light_magenta',
        'main_kanji'    => 'light_green',
        'marker_r'      => 'pale_red',
        'marker_g'      => 'dark_cyan',
        'message'       => 'light_blue',
        'names_1'       => 'light_yellow',
        'names_header'  => 'light_yellow',
        'notedited'     => 'dark_red',
        'onyomi'        => 'light_cyan',
        'particle'      => 'light_green',
        'pref1'         => 'light_blue',
        'pref2'         => 'light_gray',
        'remark'        => 'light_blue',
        'rem_text'      => 'light_gray',
        'rusnick'       => 'light_gray',
        'strokes'       => 'dark_gray',
        'transcr_cyan'  => 'light_cyan',
        'transcr_red'   => 'pale_red',
        'tango_header'  => 'light_yellow',
        'tan_title'     => 'light_cyan',
        'utility'       => 'light_gray',
    );

$colors{$_} = console_code($colors{$_}) foreach ( keys %colors ); 

%colors = (%colors, %console_codes);

# Превращает имя цвета в код
sub color ( $ ) {
    my ($color) = @_;
    defined $color or fail;
    
    return $color if ( $color =~ /^\033/ );
    
    exists $colors{$color} or fail "Wrong color name: '$color'";
    
    return $colors{$color};
}

# Выбирает более "бледный" выриант цвета.
sub pale ( $ ) {
    my ($color) = @_;
    
    $color = color($color);
    
    if ( defined $pale_map{$color} ) {
        return $pale_map{$color};
    }
    # else
    return $color;
}

# Печатает таблицу с цветами (для отладки).
sub colors_table {
    for ( my $i = 30; $i < 41; $i++ ) {
        print "$i - >\033[${i}mTEST\033[0m<\n";
    }
	for ( my $i = 90; $i < 100; $i++ ) {
        print "$i - >\033[${i}mTEST\033[0m<\n";
    }
}

sub set_color_map { 
    my ($new_colors, $new_pale_map) = @_;
    
    %colors = %$new_colors;
    %pale_map = %$new_pale_map;
}

# Вычисление реальной длины строки в терминале, т. е. с учётом "пустых"
# символов (цветовые коды) и широких символов (иероглифы и кана).

# TODO: libtext-charwidth-perl

sub size {
    my ($txt) = @_;
    
	$txt =~ s/\033\[[^m]*m//g; # убираем все цвета
    $txt !~ /\033/ or fail;
    $txt !~ /[\^#]/ or fail; # Не применяется на atext
   
    my $res = 0; # результат - длина строки
    
    my $len = length($txt); # длина $txt
    for ( my $i=0; $i < $len; $i++ ) {
        my $c = substr($txt, $i, 1); # перебираем все символы
        
        my $code = ord($c);
        if ( $code < 10000 ) { # "обычные" сиволы
            $res += 1;
        }
        elsif ( $code > 12200 && $code < 12600 ) {
            $res += 2; # кана
        }
        elsif ( $code > 19900 && $code < 41000 ) {
            $res += 2; # иероглифы
        }
        else {
            fail "size: unknown: $c $code";
        }
    }
    
    $res eq int($res) or fail "Result should be int!";
    
    return $res;
}

## "Main" function ##
sub print_article {
    ($dom) = @_; # NOT my, but global
    
    my $out = '';
    my $tmp = '';
    
    $out .= $dom->{'article_num'}.": ";
    
    $out .= print_object ( $dom->{'main_kanji'} );
    $out .= "  ";
    $out .= print_object ( $dom->{'rusnick'} );
    $out .= "  ";
    $out .= print_object ( $dom->{'strokes_num'} );
    $out .= "  ";
    $out .= print_object ( $dom->{'utility'} ) if $dom->{'utility'};
    $out .= "\n";
    
    $tmp = "   ".print_object ( $dom->{'onyomi'} );
    $tmp .= "   ".print_object( $dom->{'remarks_glob'} );
    
    $out .= $tmp."\n\n" if $tmp ne '';

    # Kun table
    $tmp = print_object ( $dom->{'kun_table'} );

    $out .= $tmp."\n\n"  if $tmp ne '';

    if ( defined $dom->{'message'} ) {
        $out .= print_object($dom->{'message'});
        $out .= "\n\n";
    }
    
    if ( defined $dom->{'tango'} ) {
        if ( defined $dom->{'tango_header'} ) {
            $out .= print_object($dom->{'tango_header'})."\n\n";
        }
        
        $tmp = print_object( $dom->{'tango'} );
        
        $out .= $tmp."\n\n"  if $tmp ne '';
    }
    
    if ( $dom->{'names'} || $dom->{'names_list'} ) {
        $out .= print_object ( $dom->{'names_header'} )."\n";
        
        if ( $dom->{'names_list'} ) {
            # "Центровка" надписи.
            $tmp = print_object ( $dom->{'names_list'} );
            my $sz = size ($tmp);
            if ( $sz < 17 ) {  $out .= " " x ( (17 - $sz) / 2 );  }
            $out .= " ".$tmp;
            $out .= "\n";
        }
        $out .= "\n";
        
        if ( $dom->{'names'} ) {
            $tmp = print_object( $dom->{'names'} );
            
            $out .= $tmp."\n\n"  if $tmp ne '';
        }
    }
    
    if ( defined $dom->{'footer'} ) {
        $tmp = atext_colored ('footer', $dom->{'footer'});
        
        $out .= print_object($tmp)."\n" if $tmp ne '';
    }
    
    return $out;
}

sub print_object {
    my ($obj) = @_;
    
    return '' if !defined $obj;
    
    my $cstack = new_cstack();
    
    my $res = '';
    
    my $ref = ref($obj);
    
    if ( $ref eq '' ) { # строка
        $res = print_atext($obj, $cstack);
    }
    elsif ( $ref eq 'HASH' ) { # объект
        defined $obj->{'type'} or fail "Invalid object";
        
        my $type = $obj->{'type'};
        
        if ( $type eq 'vtable' ) {
            $res = print_vtable($obj, $cstack);
        }
        elsif ( $type eq 'htable' ) {
            $res = print_htable($obj, $cstack);
        }
        else {
            fail "Unknown object type: '$type'";
        }
    }
    else {
        fail "Unhandled reftype: '$ref'";
    }
    
    return $res;
}

sub object_pale {
    my ($obj) = @_;
    
    return if !defined $obj;
    
    my $ref = ref($obj);
    
    if ( $ref eq '' ) { # строка
        $_[0] = atext_pale($obj);
    }
    elsif ( $ref eq 'HASH' ) { # объект
        defined $obj->{'type'} or fail "Invalid object";
        
        my $type = $obj->{'type'};
        
        if ( $type eq 'vtable' || $type eq 'htable' ) {
            $_[0]->{'pale'} = 1;
        }
        else {
            fail "Unknown object type: '$type'";
        }
    }
    else {
        fail "Unhandled reftype: '$ref'";
    }
}

sub print_atext {
    my ($atxt, $cstack) = @_;
    
    defined $atxt or fail;
    defined $cstack or fail;
        
    my $res = '';
    
    my $atxt_orig = $atxt;
    
    while ($atxt ne '') {
        my $atxt_prev = $atxt;
        
        if ( $atxt =~ s/^[^#\^]+//) {
            my $txt = $&;
            my $cur_color = cur_color($cstack);
            if ( $cur_color ne $nocolor ) {
                $txt =~ s/\n/$nocolor\n$cur_color/g; # Контролируем цвет на разрывах строк
            }
            $res .= $txt;
        }
        elsif ( $atxt =~ s/^\^([^#\^]*)#// ) {
            my $tag = $1;
            
            if ( $tag =~ /^C([a-z1-9_]+)$/ ) {
                my $color = $1;
                my $cur_color = cur_color($cstack);
                if ( $color eq 'same' ) {
                    $color = $cur_color;
                }
                $color = push_cstack ( $cstack, $color );
                $res .= $color if $color ne $cur_color;
            }
            elsif ( $tag =~ /^CX$/ ) {
                my $cur_color = cur_color($cstack);
                my $color = pop_cstack($cstack, 'color');
                $res .= $color if $color ne $cur_color;
            }
            elsif ( $tag =~ /^[PI]$/ ) { # pale or italic
                my $mod = undef;
                if ($tag eq 'P') { $mod = 'pale' } 
                elsif ($tag eq 'I') { $mod = 'italic' }
                else { fail }
                
                my $cur_color = cur_color($cstack);
                my $color = push_cstack ($cstack, $mod);
                $res .= $color if $color ne $cur_color;
            }
            elsif ( $tag =~ /^[PI]X$/ ) { # pale or italic OFF
                my $mod = undef;
                if ($tag eq 'PX') { $mod = 'pale' } 
                elsif ($tag eq 'IX') { $mod = 'italic' }
                else { fail }
                
                my $cur_color = cur_color($cstack);
                my $color = pop_cstack ($cstack, $mod);
                $res .= $color if $color ne $cur_color;
            }
            elsif ( $tag =~ /^K(\d{4})(.)$/ ) { # kanji
                my $id = $1;
                my $chr = $2;
                
                $res .= $chr;
            }
            elsif ( $tag =~ /^T(\d{5})$/ ) { # tango block
                # Do nothing
            }
            elsif ( $tag =~ /^TX$/ ) { # tango block
                # Do nothing
            }
            else {
                fail "Unknown or wrong tag: '$tag'";
            }
        }
        
        $atxt ne $atxt_prev or fail "Inf loop: '$atxt'";
    }
    
    # Мог остаться незакрытый италик
    if ( $cstack->{'italic'} ) {
        if ( $res !~ /\e\[0m[^\e]*$/ ) {
            $res .= $nocolor;
        }
        $cstack->{'italic'} = 0;
        errmsg "Warning! Non-closed italic.";
    }
    
    # Проверяем, что не осталось открытых цветов
    !@{$cstack->{'colors'}} or fail;
    !$cstack->{'pale'} or fail;
    !$cstack->{'italic'} or fail;
    
    return $res;
}

# CStack

sub new_cstack() {
    return {'colors'=>[], 'pale'=>0, 'italic'=>0 }
}

sub pop_cstack {
    my ($cstack, $what) = @_;
    
    if ( $what eq 'color' ) {
        my $colors = $cstack->{'colors'};
        @$colors or fail "Color stack should be not empty";
        pop @$colors;
    }
    elsif ( $what eq 'pale' ) {
        $cstack->{'pale'} > 0 or fail;
        $cstack->{'pale'}-- if $cstack->{'pale'} > 0;
    }
    elsif ( $what eq 'italic' ) {
        # Может вызываться pop_cstack при $cstack->{'italic'} == 0, когда
        # происходит перевод строки.
        $cstack->{'italic'}-- if $cstack->{'italic'} > 0;
    }
    return cur_color($cstack);
}

sub push_cstack {
    my ($cstack, $color) = @_;
    defined $cstack or fail;
    defined $color or fail;
    
    if ( $color eq 'pale' ) {
        $cstack->{'pale'}++;
    }
    elsif ( $color eq 'italic' ) {
        $cstack->{'italic'}++;
    }
    else {
        ref_push $cstack->{'colors'}, color($color);
    }
    return cur_color($cstack);
}

sub cur_color {
    my ($cstack) = @_;
    defined $cstack or fail;
    
    my $res = $nocolor;
    
    my $colors = $cstack->{'colors'};
    
    if ( @$colors ) {
        $res = $colors->[$#$colors]; # the last elem
    }
    
    if ( $cstack->{'pale'} ) {
        $res = pale($res);
    }
    
    if ( $cstack->{'italic'} ) {
        $res = pale($res);
    }
    
    return $res;
}

sub print_vtable {
    my ( $obj, $cstack ) = @_;
    defined $obj && ref($obj) eq 'HASH' or fail;
    defined $cstack && ref($cstack) eq 'HASH' or fail;
    
    return '' if ( !defined $obj->{'children'} || @{$obj->{'children'}} == 0 );

    my $pale = ( defined $obj->{'pale'} && $obj->{'pale'} );
    
    my $out = '';
    
    my $children = $obj->{'children'};
    my $N = @$children;
    for ( my $i = 0; $i < $N; $i++ ) {
        next unless defined  $children->[$i];

        # Разделяем блоки
        if ( $i > 0 ) {
            $out .= "\n";
            if ( defined $obj->{'spacing'} ) {
                $out .= "\n" x int($obj->{'spacing'}); # extra spacing
            }
        }

        if ( $pale ) {
            object_pale( $children->[$i] );
        }
        
        $out .= print_object ( $children->[$i] );
    }
    
    return $out;
}

# Print the horisontal table
sub print_htable {
    my ($obj, $cstack) = @_;

    if ( defined $obj->{'pale'} && $obj->{'pale'} ) {
        object_pale( $obj->{'left'} );
        object_pale( $obj->{'right'} );
    }
    
    my $column_left = ( print_object($obj->{'left'}) or '');
    my $column_right = ( print_object($obj->{'right'}) or '');

    my @column_left = split /\n/, $column_left;
    my @column_right = split /\n/, $column_right;

    my $out = '';
    
    my $right_lines_num = @column_right;
    
    my $left_column_width = 0;
    my $i = 1;
    foreach ( @column_left ) {
        last if ( $right_lines_num < $i++ ); # Не считаем ширину левого столбца, если справа строки кончились
        my $len = size($_);
        $left_column_width = $len if ( $len > $left_column_width);
    }
    
    $left_column_width += $obj->{'spacing'} if defined $obj->{'spacing'};
    
    while ( @column_left > 0 || @column_right > 0 ) {
        my $left_line = (shift @column_left or '');
        my $right_line = (shift @column_right or '');
        
        $out .= $left_line;
        $out .= chr($nbsp) x ($left_column_width - size($left_line));
        #$out .= '|';
        $out .= $right_line;
        $out .= "\n" if (@column_left > 0 || @column_right > 0);
    }
    
    return $out;
}

1;
