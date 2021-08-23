package App::TaggedDirUtils;

use 5.010001;
use strict;
use warnings;
use Log::ger;

#use File::chdir;

# AUTHORITY
# DATE
# DIST
# VERSION

our %SPEC;

$SPEC{':package'} = {
    v => 1.1,
    summary => 'CLI utilities related to tagged directories',
};

our %argspecs_common = (
    prefixes => {
        summary => 'Changes file',
        schema => ['array*', of=>'dirname*'],
        req => 1,
        pos => 0,
        slurpy => 1,
        description => <<'_',

Location(s) to search for tagged subdirectories, i.e. directories which have
some file with specific names in its root.

_
    },
);

$SPEC{list_tagged_dirs} = {
    v => 1.1,
    summary => 'Search tagged directories recursively in a list of places',
    description => <<'_',

Note: when a datadir is found, its contents are no longer recursed to search for
other datadirs.

_
    args => {
        %argspecs_common,
        detail => {
            schema => 'bool*',
            cmdline_aliases => {l=>{}},
        },
        has_tags => {
            'x.name.is_plural' => 1,
            'x.name.singular' => 'has_tag',
            schema => ['array*', of=>'str*'],
        },
        lacks_tags => {
            'x.name.is_plural' => 1,
            'x.name.singular' => 'lacks_tag',
            schema => ['array*', of=>'str*'],
        },
        has_files => {
            'x.name.is_plural' => 1,
            'x.name.singular' => 'has_file',
            schema => ['array*', of=>'filename*'],
        },
        lacks_files => {
            'x.name.is_plural' => 1,
            'x.name.singular' => 'lacks_file',
            schema => ['array*', of=>'filename*'],
        },
    },
    examples => [
        {
            summary => 'How many datadirs are here?',
            src => '[[prog]] --has-tag datadir --lacks-file .git . | wc -l',
            src_plang => 'bash',
            test => 0,
            'x.doc.show_result' => 0,
        },
        {
            summary => 'List all media tagged directories in all my external drives (show name as well as path)',
            src => '[[prog]] --has-tag media --lacks-file .git -l /media/budi /media/ujang',
            src_plang => 'bash',
            test => 0,
            'x.doc.show_result' => 0,
        },
        {
            summary => 'Backup all my mediadirs to Google Drive',
            src => q{[[prog]] --has-tag media --lacks-file .git -l /media/budi /media/ujang | td map '"rclone copy -v -v $_->{abs_path} mygdrive:/backup/$_->{name}"' | bash},
            src_plang => 'bash',
            test => 0,
            'x.doc.show_result' => 0,
        },
    ],
};
sub list_tagged_dirs {
    require Cwd;
    require File::Basename;
    require File::Find;

    my %args = @_;
    @{ $args{prefixes} }
        or return [400, "Please specify one or more directories in 'prefixes'"];

    my @prefixes;
    for my $prefix (@{ $args{prefixes} }) {
        (-d $prefix) or do {
            log_error "Not a directory '$prefix', skip searching datadirs in this directory";
            next;
        };
        push @prefixes, $prefix;
    }

    my @rows;
    File::Find::find(
        {
            preprocess => sub {
                my $matches;
              FILTER: {
                    if ($args{has_tags}) {
                        for my $tag (@{ $args{has_tags} }) {
                            last FILTER unless -e ".tag-$tag";
                        }
                    }
                    if ($args{lacks_tags}) {
                        for my $tag (@{ $args{lacks_tags} }) {
                            last FILTER if -e ".tag-$tag";
                        }
                    }
                    if ($args{has_files}) {
                        for my $file (@{ $args{has_files} }) {
                            last FILTER unless -e $file;
                        }
                    }
                    if ($args{lacks_files}) {
                        for my $file (@{ $args{lacks_files} }) {
                            last FILTER if -e $file;
                        }
                    }
                    $matches++;
                }
                if ($matches) {
                    #log_trace "TMP: dir=%s", $File::Find::dir;
                    my $abs_path = Cwd::getcwd();
                    defined $abs_path or do {
                        log_fatal "Cant getcwd() in %s: %s", $File::Find::dir, $!;
                        die;
                    };
                    log_trace "%s matches", $abs_path;
                    push @rows, {
                        name => File::Basename::basename($abs_path),
                        path => $File::Find::dir,
                        abs_path => $abs_path,
                    };
                    return ();
                }
                log_trace "Recursing into $File::Find::dir ...";
                my @entries;
                for my $entry (@_) {
                    next if $args{lacks_files} && (grep { $_ eq $entry } @{ $args{lacks_files} });
                    push @entries, $entry;
                }
                return @entries;
            },
            wanted => sub {
            },
        },
        @prefixes,
    );

    unless ($args{detail}) {
        @rows = map { $_->{abs_path} } @rows;
    }

    [200, "OK", \@rows, {'table.fields'=>[qw/name path abs_path/]}];
}

1;
# ABSTRACT:

=head1 SYNOPSIS

See CLIs included in this distribution.


=head1 DESCRIPTION

This distribution includes several utilities related to tagged directories:

#INSERT_EXECS_LIST

A "tagged directory" is a directory which has one or more tags: usually empty
files called F<.tag-TAGNAME>, where I<TAGNAME> is some tag name.

You can backup, rsync, or do whatever you like with a tagged directory, just
like a normal filesystem directory. The utilities provided in this distribution
help you handle tagged directories.


=head1 FAQ

=head2 Why tagged directories?

With tagged directories, you can put them in various places and not just on a
single parent directory. For example:

 media/
   2020/
     media-2020a/ -> a tagged dir
       .tag-media
       ...
     media-2020b/ -> a tagged dir
       .tag-media
       ...
   2021/
     media-2021a/ -> a datadir
       .tag-media
       ...
   etc/
     foo -> a datadir
       .tag-media
       ...
     others/
       bar/ -> a datadir
         .tag-media
         ...

As an alternative, you can also create symlinks:

 all-media/
   media-2020a -> symlink to ../media/2020/media-2020a
   media-2020b -> symlink to ../media/2020/media-2020b
   media-2021a -> symlink to ../media/2021/media-2021a
   media-2021b -> symlink to ../media/2021/media-2021b
   foo -> symlink to ../media/etc/foo
   bar -> symlink to ../media/etc/others/bar

and process entries in all-media/.
