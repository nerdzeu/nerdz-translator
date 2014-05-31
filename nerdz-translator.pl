#!/usr/bin/env perl
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
use strict;
use warnings;
no warnings 'experimental';
use v5.10.1; # minimum Perl version required - enables smart match
use open ':std', ':encoding(utf8)';
use Carp;
use File::Basename;
use File::Path;
use Getopt::Long;
use JSON -support_by_pp; # use JSON:PP for indent_length
use Pod::Usage;

# default configuration - bing_client_id and token should stay here
my $configuration = {
    # !! IMPORTANT CONFIGURATION STUFF !!
    # Please edit these lines.
    # MyMemory provider. Used as a fallback when Bing does not provide
    # a language. You may put here a valid email address to increase
    # the rate limit from 100 requests/day to 1000 requests/day.
    # This is optional.
    #mymemory_mail   => 'blabla@example.com',
    # Bing provider. You need to provide a client ID and a client secret,
    # otherwise the script won't work. Please follow the instructions
    # here: http://blogs.msdn.com/b/translation/p/gettingstarted1.aspx
    bing_client_id  => "your-client-id",
    bing_client_sec => "your-client-secret",
    # The remaining part of this conf is good as it is.
    # You may edit stuff here too, but you will alter the default values
    # (and the manual won't update automatically).
    translate_from  => "en", # -i
    translate_to    => [ "de", "hr", "en", "pt", "ro" ], # -o
    output_format   => '=to=n"=key": =qtranslated', # --output-format
    output_format_f => '=outdir/=lang/json/=outfn', # --output-file-format
    direct_output   => 0, # put a path to a dir or use -O
    output_file     => "default.json", # -f - only used when direct_output != 0
};

# End of the configuration.
# Here comes the hardcore Perl code.
Getopt::Long::Configure ("auto_version", "no_ignore_case");
our $VERSION = "1.0";

GetOptions (
    "translate-from|i=s"   => \$configuration->{translate_from},
    "translate-to|o=s"     => sub {
        $configuration->{translate_to} = [ split /,/, $_[1] ];
    },
    'set-translation=s@{2}'=> \$configuration->{manual_transl},
    "output-dir|O=s"       => \$configuration->{direct_output},
    "output-file|f=s"      => \$configuration->{output_file},
    "l"                    => \$configuration->{get_languages},
    "key|k=s"              => \$configuration->{key},
    "output-format=s"      => \$configuration->{output_format},
    "output-file-format=s" => \$configuration->{output_format_f},
    "h|help"               => sub {
        pod2usage (1);
    },
    "manual"               => sub {
        pod2usage (-exitval => 0, -verbose => 2);
    }
) || pod2usage (2);

croak "Error: you didn't configure the script. Open it and read the comments!"
    if !defined $configuration->{bing_client_id}
    or !defined $configuration->{bing_client_sec}
    or $configuration->{bing_client_id}  eq "your-client-id"
    or $configuration->{bing_client_sec} eq "your-client-secret";

my $target_str = join " ", @ARGV;
pod2usage "Error: missing parameters. Remember -k and the string to translate."
    unless $target_str
       and defined $configuration->{translate_from}
       and defined $configuration->{translate_to}
       and defined $configuration->{output_format}
       and defined $configuration->{key}
       and defined $configuration->{output_file}
       and defined $configuration->{bing_client_id}
       and defined $configuration->{bing_client_sec};
croak "Error: output_dir does not exist"
    if       $configuration->{direct_output}
    and ! -e $configuration->{direct_output};

my $manual_translations = get_manual_translations (
    $configuration->{manual_transl},
    sub {
        push @{$configuration->{translate_to}}, $_[0]
            unless $_[0] ~~ $configuration->{translate_to};
    }
);
my $bing = Bing::Translate::Proper->new (
    client_id     => $configuration->{bing_client_id},
    client_secret => $configuration->{bing_client_sec}
);
my $my_memory = MyMemory::Translate->new (
    $configuration->{mymemory_mail}
);

my $json = JSON->new->allow_nonref->relaxed->pretty->canonical
                    ->indent_length (4); # <3
my $tok  = $bing->get_token;

if (defined $configuration->{get_languages})
{
    say "Available languages: ",
        join (", ", sort @{$bing->get_languages_for_translate ($tok)});
    exit;
}

foreach my $lang (@{$configuration->{translate_to}})
{
    my $translated;
    # if --set-translations $lang x has been specified, use that
    if (exists $manual_translations->{$lang})
    {
        $translated = $manual_translations->{$lang};
    }
    # if we are translating to our source lang...
    elsif ($lang eq $configuration->{translate_from})
    {
        $translated = $target_str;
    }
    # or just translate.
    else
    {
        my $ref = $bing->provides ($lang) ? $bing : $my_memory;
        $translated = $ref->translate (
            text  => $target_str,
            from  => $configuration->{translate_from},
            to    => $lang,
            token => $tok
        );
    }
    if (exists $configuration->{direct_output} &&
        -d $configuration->{direct_output})
    {
        my $path = replace_variables ($configuration->{output_format_f},
            outdir => remove_trailing_slash ($configuration->{direct_output}),
            outfn  => $configuration->{output_file},
            lang   => $lang
        );
        my (undef, $dirs) = fileparse ($path);
        File::Path::make_path $dirs unless -d $dirs;
        my $in = {};
        if (-e $path)
        {
            open MUCH_JSON, "<", $path || die "can't open $path: $!";
            my $such_raw; $such_raw .= $_ while <MUCH_JSON>;
            close MUCH_JSON;
            eval { $in = $json->decode ($such_raw) };
            die "can't read $path as a JSON file: $@" if $@;
            if (ref ($in) ne "HASH")
            {
                print STDERR "** WARNING: ${path}'s content is not a JSON ",
                    "hash. May I erase it? Enter if I can, Ctrl-C if not.";
                <STDIN>;
                warn "erased ${path}'s content, it was not a JSON hash";
                $in = {};
            }
        }
        $in->{$configuration->{key}} = $translated;
        open  DEADBEEF, ">", $path || die "can't open $path rw: $!";
        print DEADBEEF $json->encode ($in);
        close DEADBEEF;
        say "OK - written ${lang} to ${path}";
        next;
    }
    say &replace_variables ($configuration->{output_format},
        translated  => $translated,
        qtranslated => $json->encode ($translated),
        to          => $lang,
        key         => $configuration->{key},
        n           => "\n"
    );
}

sub replace_variables
{
    my ($str, %vars) = @_;
    $str =~ s/=(@{[join "|", keys %vars]})/$vars{$1}/g;
    $str;
}

sub remove_trailing_slash
{
    substr ($_[0], -1) eq "/" ? substr ($_[0], 0, -1) : $_[0];
}

sub get_manual_translations
{
    my ($arr, $code) = @_;
    return if ref $arr ne 'ARRAY';
    my $res = {};
    for (my $i = 0; $i < scalar @$arr; $i += 2)
    {
        $res->{$arr->[$i]} = $arr->[$i + 1];
        &{$code}($arr->[$i]);
    }
    $res;
}

# proper version of Bing::Translate, without shitty code
package Bing::Translate::Proper;
use strict;
use warnings;
use Carp;
use HTTP::Request::Common 'POST';
use JSON;
use LWP::UserAgent;
use URI::Escape;

sub new
{
    my ($class, %args) = @_;
    croak "missing client_id or client_secret"
        unless exists $args{client_id}
           and exists $args{client_secret};
    $args{lwp} = LWP::UserAgent->new (agent => "bing-translate-proper/1.0");
    $args{_api_url} = "http://api.microsofttranslator.com/v2/Http.svc";
    bless \%args, $class;
}

sub get_token
{
    my $self = shift;
    my $req  = $self->{lwp}->request (
        POST 'https://datamarket.accesscontrol.windows.net/v2/OAuth2-13',
        [
            "grant_type"    => "client_credentials",
            "scope"         => "http://api.microsofttranslator.com",
            "client_id"     => $self->{client_id},
            "client_secret" => $self->{client_secret}
        ]
    );
    die "can't get auth token: ", $req->status_line unless $req->is_success;
    my $parsed_json;
    eval { $parsed_json = decode_json $req->decoded_content };
    die "can't get auth token: ", $@ if $@;
    die "can't get auth token: no access_token from response"
        if !exists $parsed_json->{access_token};
    $parsed_json->{access_token};
}

sub translate
{
    my ($self, %params) = @_;
    croak "missing from_lang, to_lang, text or token from args"
        unless exists $params{from}
           and exists $params{to}
           and exists $params{text}
           and exists $params{token};
    my $url = sprintf (
        "%s/Translate?text=%s&from=%s&to=%s&contentType=text/plain",
        $self->{_api_url},
        uri_escape ($params{text}),
        uri_escape ($params{from}),
        uri_escape ($params{to})
    );
    my $req = $self->{lwp}->request (
        $self->_build_request ($params{token}, $url)
    );
    die "can't translate: ", $req->status_line, ": ", 
        $self->_strip_tags ($req->decoded_content)
        unless $req->is_success;
    $req->decoded_content =~ />(.+?)<\/string>/;
    die "can't translate: missing translation text" unless defined $1;
    $1;
}

sub get_languages_for_translate
{
    my ($self, $tok) = @_;
    croak 'missing $tok from my args' unless defined $tok;
    my $req = $self->{lwp}->request ($self->_build_request ($tok, sprintf (
        "%s/GetLanguagesForTranslate",
        $self->{_api_url}
    )));
    die "can't obtain the languages: ", $req->status_line, ": ",
        $self->_strip_tags ($req->decoded_content)
        unless $req->is_success;
    my ($cnt, $res) = ($req->decoded_content, []);
    push @$res, $1 while $cnt =~ /<string>(.+?)<\/string>/g;
    $res;
}

sub provides
{
    # checks if a language is provided by bing.
    # Temporary until I find a decent solution which does
    # not involve making additional requests. The output
    # is false only when hr is the target language.
    lc $_[1] ne "hr";
}

sub _build_request
{
    my ($self, $token, $url) = @_;
    my $req = HTTP::Request->new (GET => $url);
    $req->header (Authorization => "Bearer ${token}");
    $req;
}

sub _strip_tags
{
    my $str = $_[1];
    $str =~ s/<(?:[^>'"]*|(['"]).*?\g1)*>//gs;
    $str;
}

1;
package MyMemory::Translate;
use strict;
use warnings;
use Carp;
use JSON;
use LWP::UserAgent;
use URI::Escape;

sub new
{
    my ($class, $mail) = @_;
    my %args = ();
    $args{email}    = $mail if defined $mail;
    $args{lwp}      = LWP::UserAgent->new (agent => "MyMemory::Translate/1.0");
    $args{_api_url} = "http://mymemory.translated.net/api";
    bless \%args, $class;
}

sub translate
{
    my ($self, %params) = @_;
    croak "missing from, to or text from args"
        unless exists $params{from}
           and exists $params{to}
           and exists $params{text};
    my $req = $self->{lwp}->get (sprintf (
        "%s/get?q=%s&langpair=%s|%s%s",
        $self->{_api_url},
        uri_escape ($params{text}),
        uri_escape ($params{from}),
        uri_escape ($params{to}),
        exists $self->{email} ? "&de=" . uri_escape ($self->{email}) : ""
    ));
    die "can't translate: ", $req->status_line, ": ", $req->decoded_content
        unless $req->is_success;
    my $json;
    eval { $json = decode_json $req->decoded_content };
    die "can't translate: $@" if $@;
    die "can't translate: got weird obj: ", $req->decoded_content
        unless exists $json->{responseData}
           and exists $json->{responseData}->{translatedText};
    $json->{responseData}->{translatedText};
}

__END__

=encoding utf8

=head1 NAME

nerdz-translator - ultimate all-in-one translator for NERDZ strings

=head1 SYNOPSIS

nerdz-translator [options] [-k key] [string_to_translate]

  Options:
    -i                   The input language.
    -o                   Comma-separated list of output languages.
    -k                   A key which represents the string you are translating.
    -l                   Shows a list of available languages, then exits.
    -O                   Enables direct output mode.
    -f                   The JSON file which will be edited if directout is on.
    -v                   Version information.
    -h                   This short help text.
    --manual             The full help text. Also available with perldoc.
    --output-format      The format string used as the output for each language
    --output-file-format Used to determine the path of the language files.
    --set-translation    Manually sets translations of different languages.

=head1 CAVEATS

Configuring the script inside the source file is B<REQUIRED> and the script
won't work without configuration. Please start reading the comments in the
source file at line 18.

=head1 OPTIONS

=over 8

=item B<--translate-from>, B<-i> I<language>

Specifies the input language. The default is 'en'.

=item B<--translate-to>, B<-o> I<language-1,language-2,...>

Comma-separated list of output languages.
The default is S<'de', 'hr', 'en', 'pt', 'ro'.>

=item B<--key>, B<-k> I<KEY>

A key which represents the string you are translating in a short form.
Like C<ERR_DUMB_USER>.

B<This parameter is required.>

=item B<--output-format> I<format-string>

The format string used as the output for each language.
Not used when B<--output-dir>, B<-o> is specified.

Available variables:

=over 4

=item B<=translated>

The translated string.

=item B<=qtranslated>

The translated string with quotes.

=item B<=to>

The language the string is being translated into.

=item B<=key>

The key specified with B<--key>, B<-k>.

=item B<=n>

A newline.

=back

Default: S<=to=n"=key": =qtranslated>

Which produces an output like:

  language_name
  "key": "value"

=item B<--output-file-format> I<format-string>

The format string used to determine the final path of the language files.
This is used only if B<--output-dir>, B<-o> is specified.

Available variables:

=over 4

=item B<=outdir>

The value of B<--output-dir>, B<-o>.

=item B<=outfn>

The value of B<--output-file>, B<-f> (or the default value).

=item B<=lang>

The language the string is being translated into.

=back

Default: S<=outdir/=lang/json/=outfn>

=item B<-l>

Shows a list of available languages. Exits immediately afterwards.

=item B<--output-dir>, B<-O> I<directory>

Enables the file output mode. It reads the JSON files with the names
specified in the B<--output-file>, B<-f> option (or the default value)
and appends the traditional JSON "key": "value" mapping.

B<NOTE:> The JSON files are read and written by the Perl's JSON module.
This means that your indentation, comments or any custom stuff which is
not pure JSON B<will probably be deleted>. However, the parser outputs
a pretty 4-spaces indented JSON which should be nice to read.

=item B<--output-file>, B<-f> I<file>

The JSON file which will be edited if B<--output-dir>, B<-O> is specified.
The final path of the JSON files will be determined by the value of
B<--output-file-format>. The default value is C<default.json>.

=item B<--set-translation> I<language-name> I<C<translation>>

This option manually sets the translation for I<language-name> to
I<translation>. It is B<recommended> to specify the I<translation> parameter
with the quotes, and it is B<mandatory> if your translation contains spaces.

This parameter is useful when you need the translation of your native
language too. Let's say that I'm an Italian native-speaker and I'm translating
in three different languages. Here's a command line which handles Italian too
without automatic translation:

  nt -i en -o ro,hr,jp -k SOMETHING --set-translation it "Sì" Yes

=item B<--version>, B<-v>

Shows the version of this program, Perl and Getopt.

=item B<--help>, B<-h>

The short version of this manual.

=item B<--manual>

The full version of this manual.

=back

=head1 DESCRIPTION

This program allows to quickly translate a string in multiple languages,
making localization a process much more easier and fun. There are
lots of options which are thoughtfully documented in the manual.

=head1 EXAMPLES

All the examples assume C<nt> as the executable file C<nerdz-translator.pl>.

=over 2

=item Basic translation with C<NO_THANKS> as the key

  nt -k "NO_THANKS" "No thanks"

=item Changing the source language

  nt -i it -k "NO_THANKS" "No grazie"

=item Changing the target languages

  nt -i it -o en,ro -k "NO_THANKS" "No grazie"

=item Changing the output format

  nt -i it -o en,ro -k "NO_THANKS" --output-format "=translated=n" "No grazie"

=item Outputting to JSON files

  nt -i it -o en,ro -k "NO_THANKS" -O "path/to/langs" "No grazie"

=item Outputting to JSON files named C<tst.json>

  nt -i it -o en,ro -k "NO_THANKS" -O "path/to/langs" -f "tst.json" "No grazie"

=item Setting the translation for English

  nt -i it -o ro -k "YES" --set-translation en "Yes" "Si"

=item Changing the output file format

  nt -k "YES" -O "some/path" --output-file-format "=outdir/=lang/=outfn" "Yes"

=item Showing the available languages from Bing

  nt -l

=back

=head1 AUTHOR

Roberto Frenna <robertof.public@gmail.com>

=head1 COPYRIGHT AND LICENSE

Copyright 2014 Roberto Frenna

This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at L<http://mozilla.org/MPL/2.0/>.

=cut