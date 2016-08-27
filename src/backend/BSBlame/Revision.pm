package BSBlame::Revision;

use strict;
use warnings;

use Data::Dumper;

use BSSrcrep;
use BSRevision;
use BSXML;

# can be set to use a specific getrev impl (coderef)
our $getrev;

sub new {
  my ($class, $rev, $idx, $getrev) = @_;
  print "BSBlame::Revision::new\n";
  return bless {
    'data' => {
      'rev' => $rev,
      'idx' => $idx,
      'getrev' => $getrev
    }
  }, $class;
}

sub init {
  my ($self) = @_;
  return if $self->{'data'}->{'lsrcmd5'};
  my $data = $self->{'data'};
  $data->{'lsrcmd5'} = $data->{'rev'}->{'srcmd5'};
  my %li;
  my $files = BSSrcrep::lsrev($data->{'rev'}, \%li);
  my ($l, $tsrcmd5);
  if (%li) {
    $data->{'lsrcmd5'} = $li{'lsrcmd5'};
    $data->{'expanded'} = 1;
    my $lrev = $data->{'getrev'}->($data->{'rev'}->{'project'},
                                   $data->{'rev'}->{'package'},
                                   $data->{'lsrcmd5'});
    $files = BSSrcrep::lsrev($lrev);
    $l = BSSrcrep::repreadxml($lrev, '_link', $files->{'_link'},
                              $BSXML::link);
    $tsrcmd5 = $li{'srcmd5'};
  } elsif ($files->{'_link'}) {
    $data->{'link'} = 1;
    $l = BSSrcrep::repreadxml($data->{'rev'}, '_link', $files->{'_link'},
                              $BSXML::link);
    my @patches = @{$l->{'patches'}->{''} || []};
    $data->{'branch'} = grep {(keys %$_)[0] eq 'branch'} @patches;
    $tsrcmd5 = $l->{'baserev'};
  }
  if ($l) {
    my $tprojid = $l->{'project'} || $data->{'rev'}->{'project'};
    my $tpackid = $l->{'package'} || $data->{'rev'}->{'package'};
    my $trev = $data->{'getrev'}->($tprojid, $tpackid, $tsrcmd5);
    $data->{'targetrev'} = BSBlame::Revision->new($trev);
  }
}

sub project {
  my ($self) = @_;
  return $self->{'data'}->{'rev'}->{'project'};
}

sub package {
  my ($self) = @_;
  return $self->{'data'}->{'rev'}->{'package'};
}

sub isexpanded {
  my ($self) = @_;
  $self->init();
  return exists $self->{'data'}->{'expanded'};
}

sub isbranch {
  my ($self) = @_;
  $self->init();
  return $self->islink() && $self->{'data'}->{'branch'};
}

sub islink {
  my ($self) = @_;
  $self->init();
  return exists $self->{'data'}->{'link'};
}

sub lsrcmd5 {
  my ($self) = @_;
  $self->init();
  return $self->{'data'}->{'lsrcmd5'};
}

sub localrev {
  my ($self, $lrev) = @_;
  $self->init();
  if ($lrev) {
    die("localrev can only be set for a link\n") unless $self->islink();
    die("localrev cannot be set twice\n") if $self->{'data'}->{'localrev'};
    $self->{'data'}->{'localrev'} = $lrev;
  }
  return $self unless $self->islink();
  return $self->{'data'}->{'localrev'};
}

sub targetrev {
  my ($self) = @_;
  $self->init();
  die("targetrev makes no sense for a non link\n")
    unless $self->islink() || $self->isexpanded();
  return $self->{'data'}->{'targetrev'};
}

sub resolved {
  my ($self, $status) = @_;
  $self->{'data'}->{'resolved'} = 1 if $status;
  return $self->{'data'}->{'resolved'};
}

sub idx {
  my ($self) = @_;
  return $self->{'data'}->{'idx'};
}

sub satisfies {
  my ($self, @constraints) = @_;
  for (@constraints) {
    next unless $_->isfor($self);
    return 0 unless $_->eval($self);
  }
  # only init if really needed
  $self->init();
  if ($self->resolved() && ($self->islink() || $self->isexpanded())) {
    return $self->targetrev()->satifies(@constraints);
  }
  return 1;
}

1;
