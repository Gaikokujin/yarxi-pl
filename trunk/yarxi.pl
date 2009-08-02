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
use FindBin;
use File::Basename;

sub BEGIN {
	unshift @INC, $FindBin::Bin;

	$| = 1; # Препятствуем кэшированию вывода.
}

use JDCommon;
use JDFormatter;
use JDPrinterC;
#----------------------------------------------------------------------

chdir $FindBin::Bin
	or fail "Failed to change dir to ".$FindBin::Bin;

my $db_filename = "yarxi_u.db";

( -f $db_filename ) or fail "Can't find database file: '$db_filename'";

our $dbh = DBI->connect( "dbi:SQLite:dbname=$db_filename", "", "");

#----------------------------------------------------------------------

my $search_show_all = 0;
#----------------------------------------------------------------------

sub read_config_file {
	my ($file) = @_;

	my $fh;
	open $fh, $file or fail "Can't open file '$file'";

	while (my $line = <$fh>) {
		chomp $line;
		$line =~ s/^\s+//;
		$line =~ s/\s+$//; # Remove spaces
		next if $line =~ /^#/; # пропускаем комметарии
		next if $line =~ /^$/; # пропускаем пустые строки

		my ($key, $value);
		if ( $line =~ /^(\S+)\s*(.*)$/ ) {
			$key = $1; $value = $2;
		}

		if ( $key eq 'cur_trans_type' ) {
			JDFormatter::set_cur_trans_type( $value );
		}
		elsif ( $key eq 'scheme' ) {
			my $dir = dirname($file);
			read_colorscheme_file( "$dir/$value" );
		}
		else {
			fail "Не могу понять строку: '$line'";
		}
	}
}

sub read_colorscheme_file {
	my ($file) = @_;

	my $fh;
	open $fh, $file or fail "Can't open file '$file'";

	my %colors;
	my %pale_map;

	while (my $line = <$fh>) {
		chomp $line;
		$line =~ s/^\s+//;
		$line =~ s/\s+$//; # Remove spaces

		next if $line =~ /^#/; # пропускаем комметарии
		next if $line =~ /^$/; # пропускаем пустые строки

		if ( $line =~ /^([A-Za-z_\d\-]+)\s+([A-Za-z_\d\-]+|\[\d+)$/ ) {
		# Определение цвета.
			my $key = $1;
			my $value = $2;

			if ( $value =~ /^\[/ ) {
			# Определение через цветовой код
				$colors{$key} = "\033".$value."m";
			}
			else {
			# Определение через уже добавленный цвет
				( defined $colors{$value} ) or fail "Цвет ещё не определён: '$value'";

				$colors{$key} = $colors{$value};
			}
		}
		elsif ( $line =~ /^([A-Za-z_\d\-]+|\[\d+)\s*>\s*([A-Za-z_\d\-]+|\[\d+)$/ ) {
		# Определение бледного цвета
			my $key = $1;
			my $value = $2;

			if ( $key !~ /^\[/ ) {
				defined $colors{$key} or fail "Цвет ещё не определён: '$key'";
				$key = $colors{$key};
			} else {
				$key = "\033".$key."m";
			}

			if ( $value !~ /^\[/ ) {
				defined $colors{$value} or fail "Цвет ещё не определён: '$value'";
				$value = $colors{$value};
			} else {
				$value = "\033".$value."m";
			}

			$pale_map{$key} = $value;
		}
		else {
			fail "Не могу понять строку: $line";
		}
	}

	JDPrinterC::set_color_map(\%colors, \%pale_map);
}

sub article {
	my ($num) = @_;
	( $num eq int($num) ) or fail;

	JDFormatter::clear();

	# Формирование статьи
	my $document = format_article($num);
	if ( !$document ) { # Нет такой статьи
		say("Нет такой статьи (Kanji $num)\n");
		return 0;
	}

	# "Рендеринг" статьи
	my $out = print_article($document);

	$document = undef; # Удаляем объекты

	say($out); # Отправляем в output

	return 1;
}

sub tango_alone {
	my ($num) = @_;
	$num or fail;
	$num eq int($num) or fail;

	JDFormatter::clear();

	# Формирование статьи
	my $document = format_tango_alone($num);
	if ( !$document ) { # Нет такой статьи
		say("Нет такой статьи (Tango $num)\n");
		return 0;
	}

	# "Рендеринг статьи" - вывод её в определённом представлении.
	my $out = JDPrinterC::print_object($document);
	$out .= "\n";

	$document = undef; # Удаляем объекты

	say $out; # Отправляем в output

	return 1;
}

sub do_test {
	my ($start) = @_;

	open STDOUT, ">/dev/null";

	my $start_time = time();
	my $i = $start;
	while ( 1 ) {
		eval {
			while ( 1 ) {
				# DBG:
				print STDERR ".";
				print STDERR "  $i\n" if ( $i % 1000 == 0 );
				article($i) or die "No more articles.";
			}
			continue {$i++}
		};
		if ($@) {
			my $res = '';
			while  ($res !~ /^[yn]$/i ) {
				#exit 0; # DBG:

				print STDERR "\n>>$i<<\n";
				print STDERR "$@\n";
				print STDERR "Continue?(y/n) ";

				$res = getc();
			}
			last if ( $res =~ /^[n]$/i );
		}
	}
	continue {$i++}

	print STDERR "\nDone in ".(time - $start_time)." seconds.\n";
}

sub do_test2 {
	my ($start) = @_;

	open STDOUT, ">/dev/null";

	my $i = $start;
	while (1) {
		eval {
			while ( 1 ) {
				# DBG:
				print STDERR ".";
				print STDERR "  $i\n" if ( $i % 1000 == 0 );
				tango_alone($i) or die "No more articles";
			}
			continue {$i++}
		};
		if ($@) {
			my $res = '';
			while  ($res !~ /^[yn]$/i ) {
				print STDERR "\n>>$i<<\n";
				print STDERR "$@\n";
				#last if $i == 45252;
				#exit 0; # DBG:

				print STDERR "Continue?(y/n) ";
				$res = getc();
			}
			last if ( $res =~ /^[n]$/i );
		}

	}
	continue {$i++}

	print STDERR "\nDone.\n";
}

# Пока не используется
sub get_term_size {
	my $res;

	$res = system('which tput >/dev/null 2>&1');
	return undef if $res != 0;

	my $cols = `tput cols`;
	return undef if $? != 0;
	my $lines = `tput lines`;
	return undef if $? != 0;

	chomp $cols; chomp $lines;

	return ($cols, $lines);
}
#----------------------------------------------------------------------

# Поиск

sub search_lat {
	my ($txt) = @_;

	# Точный поиск в Kanji
	search_kunyomi($txt) and return 1;

	# Точный поиск в Tango
	search_tango_reading($txt) and return 1;

	return 0;
}

sub search_kunyomi {
	my ($txt) = @_;

	$txt =~ s/'//g; # Убираем кавычки для безопасности

	$txt =~ s/^\.+/%/;
	$txt =~ s/\.+$/%/;

	$txt = '%*'.$txt if $txt !~ /^%/;
	$txt = $txt.'*%' if $txt !~ /%$/;

	my $sth = $dbh->prepare("SELECT Nomer, Uncd FROM Kanji WHERE (Kunyomi LIKE '$txt')");
	$sth->execute();

	return kanji_results( $sth );
}

sub kanji_results {
	my ($sth) = @_;

	my @rows = ();

	while ( my $row = $sth->fetchrow_hashref() ) {
		push @rows, $row;
	}

	return 0 if !@rows;

	my $first = shift @rows;
	article ( $first->{'Nomer'} );
	if ( @rows ) {
		say("\nТакже найдено в статьях: ");
		for (my $i=0; $i<100 && @rows; $i++ ) {
			say( chr((shift @rows)->{'Uncd'})." " );
		}
		say " плюс ещё ".int(@rows)." статей..." if ( @rows );
		print "\n";
	}

	return 1;
}

sub search_tango_reading {
	my ($txt) = @_;

	$txt =~ s/'//g; # Убираем кавычки для безопасности

	$txt =~ s/^\.+/%/;
	$txt =~ s/\.+$/%/;

	my $sql =
			"SELECT Nomer FROM Tango"
			." WHERE (Reading LIKE '$txt')"
			.($txt =~ /^%/ ? $txt =~ /%$/ ?
				"" : " OR (Reading LIKE '$txt*%')" :
			" OR (Reading LIKE '$txt*%') OR (Reading LIKE '%*$txt*%')");

	my $sth = $dbh->prepare( $sql );
	$sth->execute();

	return tango_results( $sth );
}

sub tango_results {
	my ($sth) = @_;

	my @rows = ();

	while ( my $row = $sth->fetchrow_hashref() ) {
		push @rows, $row;
	}

	return 0 if !@rows;

	for ( my $i=0; $i<25 && @rows || $search_show_all; $i++ ) {
		my $row = shift @rows;
		last if !defined $row;
		tango_alone ( $row->{'Nomer'} );
	}
	if ( @rows ) {
		say "\n... плюс ещё ".int(@rows)." слов."
			." Используйте ключ -a, чтобы увидеть все найденные результаты.\n";
	}

	return 1;
}

sub search_unicode {
	my ($uncd) = @_;

	my $sth = $dbh->prepare("SELECT Nomer FROM Kanji WHERE Uncd='$uncd'");
	$sth->execute();

	my $row = $sth->fetchrow_hashref();

	return 0 if !$row;

	article( $row->{'Nomer'} );

	return 1;
}

sub search_onyomi {
	my ($txt) = @_;

	$txt =~ s/'//g; # Убираем кавычки для безопасности

	$txt =~ s/^\.+/%/;
	$txt =~ s/\.+$/%/;

	$txt = '%*'.$txt if $txt !~ /^%/;
	$txt = $txt.'*%' if $txt !~ /%$/;

	my $sth = $dbh->prepare("SELECT * FROM Kanji WHERE (Onyomi LIKE '$txt')");
	$sth->execute();

	return kanji_results( $sth );
}

sub search_rus {
	my ($txt) = @_;

	# Точный поиск в Kanji.RusNick
	search_kunyomi_rusnick($txt) and return 1;

	# Неточный поиск в Kanji.Russian
	search_kunyomi_russian($txt) and return 1;

	# Неточный поиск в Tango.Russian
	search_tango_russian($txt) and return 1;

	return 0;
}

sub search_kunyomi_rusnick {
	my ($txt) = @_;

	$txt =~ s/'//g; # Убираем кавычки для безопасности

	$txt =~ s/^\.+/%/;
	$txt =~ s/\.+$/%/;

	my $sth = $dbh->prepare("SELECT Nomer, Uncd FROM Kanji WHERE (RusNick LIKE '$txt')");
	$sth->execute();

	return kanji_results( $sth );
}

sub search_kunyomi_russian {
	my ($txt) = @_;

	$txt =~ s/'//g; # Убираем кавычки для безопасности

	$txt =~ s/^\.+/%/;
	$txt =~ s/\.+$/%/;

	$txt = '%'.$txt if $txt !~ /^%/;
	$txt = $txt.'%' if $txt !~ /%$/;

	my $sth = $dbh->prepare("SELECT Nomer, Uncd FROM Kanji WHERE (Russian LIKE '$txt')");
	$sth->execute();

	return kanji_results( $sth );
}

sub search_tango_russian {
	my ($txt) = @_;

	$txt =~ s/'//g; # Убираем кавычки для безопасности

	$txt =~ s/^\.+/%/;
	$txt =~ s/\.+$/%/;

	$txt = '%'.$txt if $txt !~ /^%/;
	$txt = $txt.'%' if $txt !~ /%$/;

	my $sth = $dbh->prepare(
			"SELECT Nomer FROM Tango WHERE (Russian LIKE '$txt')"
		);
	$sth->execute();

	return tango_results( $sth );
}


sub search_compound {
	my ($txt) = @_;

	my @arr = ();

	while ( $txt =~ /([一-龥])/g ) { # выделяем иероглифы
		my $uncd = ord ($1);

		my $sth = $dbh->prepare("SELECT Nomer FROM Kanji WHERE Uncd='$uncd'");
		$sth->execute();

		my $row = $sth->fetchrow_hashref();

		if ( !$row ) {
			say "Знак ".chr($uncd)." (Uncd: $uncd) игнорируется\n";
			next;
		}

		$arr[@arr] = $row->{'Nomer'};
	}

	if ( !@arr ) {
		say "В слове не найдено иероглифов\n";
		return 0;
	}

	my $sql = "SELECT Nomer FROM Tango WHERE";
	my $where = "";
	foreach ( @arr ) {
		$where .= " AND" if $where;
		$where .= " (K1=$_ OR K2=$_ OR K3=$_ OR K4=$_)";
	}
	$sql .= $where;

	my $sth = $dbh->prepare($sql);
	$sth->execute();

	return tango_results( $sth );
}
#----------------------------------------------------------------------

sub print_kana_table {
	say <<HEREDOC;
 ва  ра   я  ма  ха  на  та  са  ка   а
 わ  ら  や  ま  は  な  た  さ  か  あ - а
  н  り   ю  み  ひ  に  ち  し  き  い - и
 ん  る  ゆ  む  ふ  ぬ  つ  す  く  う - у
  о  れ   ё  め  へ  ね  て  せ  け  え - э
 を  ろ  よ  も  ほ  の  と  そ  こ  お - о

		  я    ба па    да   дза  га  а
 ゎ      ゃ    ば ぱ    だ   ざ  が  ぁ - а
 ゐ       ю    び ぴ    ぢ   じ  ぎ  ぃ - и
 ゑ      ゅ    ぶ ぷ   っづ  ず  ぐ  ぅ - у
 ゝ       ё    べ ぺ    で   ぜ  げ  ぇ - э
 ゞ      ょ    ぼ ぽ    ど   ぞ  ご  ぉ - о
-------------------------------------------
 ВА  РА   Я  МА  ХА  НА  ТА  СА  КА   А
 ワ  ラ  ヤ  マ  ハ  ナ  タ  サ  カ  ア - А
  Н  リ   Ю  ミ  ヒ  ニ  チ  シ  キ  イ - И
 ン  ル  ユ  ム  フ  ヌ  ツ  ス  ク  ウ - У
  О  レ   Ё  メ  ヘ  ネ  テ  セ  ケ  エ - Э
 ヲ  ロ  ヨ  モ  ホ  ノ  ト  ソ  コ  オ - О
-------------------------------------------
 ヮ       Я    БА ПА    ДА   ДЗА ГА   А
 ヰ      ャ    バ パ    ダ   ザ  ガ  ァ - А
 ヱ       Ю    ビ ピ    ヂ   ジ  ギ  ィ - И
 ヴ      ュ    ブ プ   ッヅ  ズ  グ  ゥ - У
 ヵ       Ё    ベ ペ    デ   ゼ  ゲ  ェ - Э
 ヶ      ョ    ボ ポ    ド   ゾ  ゴ  ォ - О

HEREDOC

	#my $start = ord("あ")-3;
	#for ( my $i=$start; $i <  $start+200; $i++ ) {
		#say "(".chr($i).") - $i\n";
	#}
	return;
}
#----------------------------------------------------------------------

sub about {
	say <<HEREDOC;
Yarxi.PL - 2007-2009 (c) Андрей Смачёв aka Biga.

Консольный интерфейс к словарю Yarxi.

Оригинальная программа (Яркси) и база данных словаря - (c) Вадим Смоленский.
(http://www.susi.ru/yarxi/)
HEREDOC
}
#----------------------------------------------------------------------

sub print_help {
	about();

	say <<HEREDOC;

Использование:
yarxi.pl [опция] [что искать] [-a]

Слово для поиска может быть:
* Числом, например 1234. Тогда будет показана статья с этим номером.
* Слово латинскими буквами. Будет произведён поиск в транскрипциях
	(кунъёми и составные слова).
* Слово русскими буквами. Будет искаться в "базовых значениях" иероглифов,
	значениях кунъёми и составных слов.
* Единичный иероглиф. Будет осуществлён поиск соответствующей статьи.
* Слово на японском. Кана будет проигнорирована. Из слова будут выделены
	иероглифы, и будет произведён поиск составных слов, содержащих
	все эти иероглифы без учёта порядка.

В слове для поиска можно использовать символ подчёркивания "_" для
обозначения произвольного (неизвестного) символа и символ процента
"%" для обозначения произвольного (в т. ч. и нулевого) числа любых
символов. Т. е. это обычная нотация оператора LIKE языка SQL.
Также, точки "." в начале и конце слова означают то же, что и "%"
(как в Яркси).

Опции:
	Там, где написано <aiueo>, подразумевается слово для поиска, записанное
	латинскими буквами. <абв> - соответственно, русскими.
	Если хотите искать что-либо с пробелами, заключайте словосочетание
	в кавычки (" или '). Например, "несколько слов".

  -a            Выводить при поиске все найденные значения. По-умолчанию
				 выводится только ограниченное число значений, если найдено
				 слишком много всего.
  -co  <KANJI>  Поиск составных слов по набору иероглифов без учёта порядка.
  --help, -h    Показ этой справки.
  -kr  <абв>    Поиск по значениям кунъёми.
  -kun <aiueo>  Поиск иероглифов с кунъёми "aiueo".
  -on  <aiueo>  Поиск иероглифов с онъёми "aiueo".
  -r   <абв>    Поиск по "базовым значениям" иероглифов, значениям
				 кунъёми и составных слов.
  -rn  <абв>    Поиск только по "базовым значениям" иероглифов.
  -t   <NUM>    Показ составного слова с номером NUM в базе данных.
  -tan <aiueo>  Поиск составных слов по чтению.
  -tr  <абв>    Поиск в значениях составных слов.
  -u   <NUM>    Поиск иероглифа по его коду в юникоде.

Дополнительные опции:

  test          Генерация всех словарных статей в целях отладки.
  test2         Генерация всех составных слов, также в целях отладки.

  kanatable     Таблица хираганы и катаканы.

HEREDOC
}

#----------------------------------------------------------------------

### BEGIN ###

# Читаем конфиги
if ( -f "config/yarxi.conf") { # Файл конфига в директории программы
	read_config_file("config/yarxi.conf");
}
if ( -f $ENV{HOME}."/.yarxi/yarxi.conf") { # Файл конфига в директории пользователя
	read_config_file( $ENV{HOME}."/.yarxi/yarxi.conf" );
}

#($term_cols, $term_lines) = get_term_size();

# Parse cmdline parameters
if ( @ARGV == 0 ) {
	about();
	say "\nДля просмотра возможностей, используйте опцию '--help'\n\n";
}
my @args = @ARGV;
utf8::decode($_) foreach @args;

# Читаем аргументы в два прохода
# В первом ищем флаги
foreach my $arg ( @args ) {
	if ( $arg eq "-a" ) {
		$search_show_all = 1;
	}
}

while ( my $arg = shift @args ) {

	if ( $arg eq '--help' || $arg eq '-h' ) {
		print_help();
	}
	elsif ( $arg eq '-t' ) { # Tango
		$arg = shift @args;

		$arg eq int($arg) or fail "Should be numeric: '$arg'";

		tango_alone( $arg );
	}
	elsif ( $arg eq '-on' ) {
		search_onyomi( shift @args ) or say "Ничего не найдено.\n";
	}
	elsif ( $arg eq '-kun' ) {
		search_kunyomi( shift @args ) or say "Ничего не найдено.\n";
	}
	elsif ( $arg eq '-tan' ) {
		search_tango_reading( shift @args ) or say "Ничего не найдено.\n";
	}
	elsif ( $arg eq '-co' ) {
		search_compound( shift @args ) or say "Ничего не найдено.\n";
	}
	elsif ( $arg eq '-tr' ) {
		search_tango_russian( shift @args ) or say "Ничего не найдено.\n";
	}
	elsif ( $arg eq '-rn' ) {
		search_kunyomi_rusnick( shift @args ) or say "Ничего не найдено.\n";
	}
	elsif ( $arg eq '-kr' ) {
		search_kunyomi_russian( shift @args ) or say "Ничего не найдено.\n";
	}
	elsif ( $arg eq '-r' ) {
		search_rus( shift @args ) or say "Ничего не найдено.\n";
	}
	elsif ( $arg eq '-u' ) {
		$arg = shift @args;
		defined $arg && $arg =~ /^\d+$/
				or fail "Ключ -u ожидает число после себя.";
		search_unicode( $arg ) or say "Ничего не найдено (".chr($arg)." - $arg).\n";
	}
	elsif ( $arg eq 'test' ) {
		my $start = shift @args;
		$start = 1 if !defined $start;
		do_test($start);
	}
	elsif ( $arg eq 'test2' ) {
		my $start = shift @args;
		$start = 1 if !defined $start;
		do_test2($start);
	}
	elsif ( $arg eq 'colormap' ) {
		colors_table();
	}
	elsif ( $arg eq 'kanatable' ) {
		print_kana_table();
	}
	elsif ( $arg =~ /^\d+$/ ) {
		article($arg);
	}
	elsif ( $arg =~ /^[%\.a-z:]/i ) {
		search_lat($arg) or say "Ничего не найдено.\n";
	}
	elsif ( $arg =~ /^[%\.а-яё]/i ) {
		search_rus($arg) or say "Ничего не найдено.\n";
	}
	elsif ( $arg =~ /^([一-龥])$/ ) {
		my $uncd = ord($1);
		search_unicode( $uncd )
			or say "Не найдено статьи для знака '".chr($uncd)."' (Uncd:$uncd).\n";
	}
	elsif ( $arg =~ /[一-龥]/ ) {
		search_compound( $arg )  or say "Ничего не найдено.\n";
	}
	elsif ( $arg =~ /^-(a)$/ ) {
		# Do nothing
	}
	else {
		errmsg ("Непонятный параметр: '$arg'");
		if ( $arg =~ /^.$/ ) {
			errmsg ("'$arg' - ".ord($arg));
		}
	}
}

exit 0;
