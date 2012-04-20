=head1 NAME

C::Utility - utilities for generating C programs

=cut

package C::Utility;
require Exporter;

@ISA = qw(Exporter);

@EXPORT_OK = qw/
                   convert_to_c_string
                   convert_to_c_string_pc
                   valid_c_variable
                   hash_to_c_file
                   ch_files
                   print_top_h_wrapper
                   print_bottom_h_wrapper
                   escape_string
                   line_directive
                   c_to_h_name
                   brute_force_line
                   add_lines
               /;

%EXPORT_TAGS = (
    'all' => \@EXPORT_OK,
);

use warnings;
use strict;

our $VERSION = '0.002';

use Carp;
use File::Spec;

=head1 DESCRIPTION

This module was released to CPAN as a helper module for
L<C::Template>. It contains simple functions which assist in automatic
generation of C programs.

=head1 FUNCTIONS

=head2  convert_to_c_string

   my $c_string = convert_to_c_string ($perl_string);

This converts a Perl string into a C string. For example, it converts

    my $string =<<EOF;
    The quick "brown" fox
    jumped over the lazy dog.
    EOF

into

    "The quick \"brown\" fox\n"
    "jumped over the lazy dog.\n"

It also removes backslashes from before the @ symbol, so \@ is
transformed to @.

=cut

sub convert_to_c_string
{
    my ($text) = @_;
    if (length ($text) == 0) {
        return "\"\"";
    }
    # Convert backslashes to double backslashes.
    $text =~ s/\\/\\\\/g;
    # Escape double quotes
    $text = escape_string ($text);
    # Undo damage
    $text =~ s/\\\\"/\\"/g;
    # Remove backslashes from before the @ symbol.
    $text =~ s/\\\@/@/g;
    # Turn each line into a string
    $text =~ s/(.*)\n/"$1\\n"\n/gm;
    # Catch a final line without any \n at its end.
    if ($text !~ /\\n\"$/) {
	$text =~ s/(.+)$/"$1"/g;
    }
    return $text;
}

=head2 convert_to_c_pc

    my $c_string = convert_to_c_pc ($string);     

As L</convert_to_c> but also with % (the percent character) converted
to a double percent, %%. This is for generating strings which may be
used as C format strings.

=cut

sub convert_to_c_string_pc
{
    my ($text) = @_;
    $text =~ s/%/%%/g;
    return convert_to_c_string ($text);
}

=head2 escape_string

   my $escaped_string = escape_string ($normal_string);

Escape double quotes (") in a string with a backslash.

=cut

sub escape_string
{
    my ($text) = @_;
    $text =~ s/\"/\\\"/g;
    return $text;
}

=head2  c_to_h_name

    my $h_file = c_to_h_name ("frog.c");
    # $h_file = "frog.h".

Make a .h file name from a .c file name.

=cut

sub c_to_h_name
{
    my ($c_file_name) = @_;
    if ($c_file_name !~ /\.c/) {
	die "$c_file_name is not a C file name";
    }
    my $h_file_name = $c_file_name;
    $h_file_name =~ s/\.c$/\.h/;
    return $h_file_name;
}

# This list of reserved words in C is from
# http://crasseux.com/books/ctutorial/Reserved-words-in-C.html

my @reserved_words = sort {length $b <=> length $a} qw/auto if break
int case long char register continue return default short do sizeof
double static else struct entry switch extern typedef float union for
unsigned goto while enum void const signed volatile/;

# A regular expression to match reserved words in C.

my $reserved_words_re = join '|', @reserved_words;

=head2 valid_c_variable

    valid_c_variable ($variable_name);

This returns 1 if C<$variable_name> is a valid C variable, the
undefined value otherwise.

=cut

sub valid_c_variable
{
    my ($variable_name) = @_;
    if ($variable_name !~ /^[A-Za-z_][A-Za-z_0-9]+$/ ||
	$variable_name =~ /^(?:$reserved_words_re)$/) {
	return;
    }
    return 1;
}

# Wrapper name
# BKB 2009-10-05 14:09:41

=head2 wrapper_name

    my $wrapper = wrapper_name ($file_name);

Given a file name, return a suitable C preprocessor wrapper name based
on the file name.

=cut

sub wrapper_name
{
    my ($string) = @_;
    $string =~ s/[.-]/_/g;
    die "Bad string '$string'" unless valid_c_variable ($string);
    my $wrapper_name = uc $string;
    return $wrapper_name;
}

=head2 print_top_h_wrapper

    print_top_h_wrapper ($file_handle, $file_name);
    # Prints #ifndef wrapper at top of file.

Print an "include wrapper" for a .h file to C<$file_handle>. For
example,

    #ifndef MY_FILE
    #define MY_FILE

The name of the wrapper comes from L</wrapper_name> applied to
C<$file_name>.

See also L</print_bottom_h_wrapper>.

=cut

sub print_top_h_wrapper
{
    my ($fh, $file_name) = @_;
    my $wrapper_name = wrapper_name ($file_name);
    print $fh <<EOF;
#ifndef $wrapper_name
#define $wrapper_name
EOF
}

=head2 print_bottom_h_wrapper

    print_bottom_h_wrapper ($file_handle, $file_name);

Print the bottom part of an include wrapper for a .h file to
C<$file_handle>.

The name of the wrapper comes from L</wrapper_name> applied to
C<$file_name>.

See also L</print_top_h_wrapper>.

=cut

sub print_bottom_h_wrapper
{
    my ($fh, $file_name) = @_;
    my $wrapper_name = wrapper_name ($file_name);
    print $fh <<EOF;
#endif /* $wrapper_name */
EOF
}

=head2 print_include

    print_include ($file_handle, $file_name);

Print an #include statement for a .h file named C<$file_name> to
C<$file_handle>:

    #include "file.h"

=cut

sub print_include
{
    my ($fh, $h_file_name) = @_;
    print $fh <<EOF;
#include "$h_file_name"
EOF
}

=head2 hash_to_c_file

    hash_to_c_file ($c_file_name, \%hash);

Output a Perl hash as a set of const char * strings. For example,

    hash_to_c_file ('my.c', { version => '0.01', author => 'Michael Caine' });

prints

    #include "my.h"
    const char * version = "0.01";
    const char * author = "Michael Caine";

to F<my.c>, and 

    #ifndef MY_H
    #define MY_H
    extern const char * version;
    extern const char * author;
    #endif

to F<my.h>.

The keys of the hash are checked with L</valid_c_variable>, and the
routine dies if they are not valid C variable names.

A third argument, C<$prefix>, contains an optional prefix to add to
all the variable names:

    hash_to_c_file ('that.c', {ok => 'yes'}, 'super_');

prints

    const char * super_ok = "yes";

=cut

sub hash_to_c_file
{
    # $prefix is an optional prefix applied to all variables.
    my ($c_file_name, $hash_ref, $prefix) = @_;
    my $h_file_name = ch_files ($c_file_name);
    die "Not a hash ref" unless ref $hash_ref eq "HASH";
    $prefix = "" unless $prefix;
    open my $c_out, ">:utf8", $c_file_name or die $!;
    print_include ($c_out, $h_file_name);
    open my $h_out, ">:utf8", $h_file_name or die $!;
    print_top_h_wrapper ($h_out, $h_file_name);
    for my $variable (sort keys %$hash_ref) {
	if (!valid_c_variable ($variable)) {
	    die "bad variable $variable";
	}
	my $value = $hash_ref->{$variable};
	$value = escape_string ($value);
	print $c_out "const char * $prefix$variable = \"$value\";\n";
	print $h_out "extern const char * $prefix$variable; /* $value */\n";
    }
    close $c_out or die $!;
    print_bottom_h_wrapper ($h_out, $h_file_name);
    close $h_out or die $!;
}

=head2 line_directive

     line_directive ($fh, 42, "file.x")

prints

     #line 42 "file.x"

This prints a C preprocessor line directive to the file specified by
C<$fh>.

=cut

sub line_directive
{
    my ($output, $line_number, $file_name) = @_;
    die "$line_number is not a real line number"
	unless $line_number =~ /^\d+$/;
    print $output "#line $line_number \"$file_name\"\n";
}

=head2 brute_force_line

    brute_force_line ($input_file, $output_file);

Put #line directives on every line of a file. This is a fix used to
force line numbers into a file before it is processed by L<Template>.

=cut

sub brute_force_line
{
    my ($input_file, $output_file) = @_;
    open my $input, "<:encoding(utf8)", $input_file or die $!;
    open my $output, ">:encoding(utf8)", $output_file or die $!;
    while (<$input>) {
        print $output "#line $. \"$input_file\"\n";
        print $output $_;
    }
    close $input or die $!;
    close $output or die $!;
}

=head2 add_lines

    my $text = add_lines ($file);

Replace strings of the form #line in the file specified by C<$file>
with a C-style line directive before it is processed by L<Template>.

=cut

sub add_lines
{
    my ($input_file) = @_;
    my $full_name = File::Spec->rel2abs ($input_file);
    my $text = '';
    open my $input, "<:encoding(utf8)", $input_file or die $!;
    while (<$input>) {
        if (/^#line/) {
            my $line_no = $. + 1;
            $text .= "#line $line_no \"$full_name\"\n";
        }
        elsif ($. == 1) {
            $text .= "#line 1 \"$full_name\"\n";
            $text .= $_;
        }
        else {
            $text .= $_;
        }
    }
    return $text;
}

=head1 SEE ALSO

=over

=item L<C::Template>

=back

=head1 AUTHOR

Ben Bullock, <bkb@cpan.org>

=head1 COPYRIGHT AND LICENSE

This module and its associated files are copyright (C) 2012 Ben
Bullock. They may be copied, used, modified and distributed under the
same terms as the Perl programming language.

=cut

1;
