package BSBlame::Revision;

use strict;
use warnings;

use Data::Dumper;
use Digest::MD5 ();

use BSSrcrep;
use BSRevision;
use BSXML;

sub new {
  my ($class, $rev, $revmgr, $idx) = @_;
  print "BSBlame::Revision::new\n";
  return bless {
    'data' => {
      'rev' => $rev,
      'revmgr' => $revmgr,
      'idx' => $idx
    }
  }, $class;
}

sub init {
  my ($self, $lrev, $trev) = @_;
  return if $self->{'data'}->{'lsrcmd5'};
  die("trev without lrev makes no sense\n") if $trev && !$lrev;
  my $data = $self->{'data'};
  $data->{'lsrcmd5'} = $data->{'rev'}->{'srcmd5'};
  my %li;
  my $files = BSSrcrep::lsrev($data->{'rev'}, \%li);
  my ($l, $tsrcmd5);
  if (%li) {
    $data->{'lsrcmd5'} = $li{'lsrcmd5'};
    $data->{'expanded'} = 1;
    my $lrev = $data->{'revmgr'}->intgetrev($data->{'rev'}->{'project'},
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
  if ($l && !$trev) {
    my $tprojid = $l->{'project'} || $data->{'rev'}->{'project'};
    my $tpackid = $l->{'package'} || $data->{'rev'}->{'package'};
    $trev = $data->{'revmgr'}->intgetrev($tprojid, $tpackid, $tsrcmd5);
    $data->{'targetrev'} = BSBlame::Revision->new($trev, $data->{'revmgr'});
  } elsif ($trev) {
    $self->localrev($lrev);
    $data->{'targetrev'} = $trev;
    $self->resolved(1);
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

sub isplain {
  my ($self) = @_;
  return !$self->islink() && !$self->isexpanded();
}

sub lsrcmd5 {
  my ($self) = @_;
  $self->init();
  return $self->{'data'}->{'lsrcmd5'};
}

sub srcmd5 {
  my ($self) = @_;
  return $self->{'data'}->{'rev'}->{'srcmd5'};
}

sub time {
  my ($self) = @_;
  die("time cannot be requested for an expanded rev\n") if $self->isexpanded();
  return $self->{'data'}->{'rev'}->{'time'};
}

sub localrev {
  my ($self, $lrev) = @_;
  $self->init();
  my $data = $self->{'data'};
  if ($lrev) {
#    die("localrev cannot be set for a plain rev\n") if $self->isplain();
    die("localrev cannot be changed\n") if $data->{'localrev'}
      && $data->{'localrev'} != $lrev; # XXX: use ref comparison
    $data->{'localrev'} = $lrev;
  }
#  return $self if $self->isplain();
  return $self if $self->resolved() && !$data->{'localrev'};
  return $data->{'localrev'};
}

sub targetrev {
  my ($self) = @_;
  $self->init();
  die("targetrev makes no sense for a non link\n") if $self->isplain();
  return $self->{'data'}->{'targetrev'};
}

sub intrev {
  my ($self) = @_;
  my $lrev = $self->localrev();
  return $lrev->intrev() if $lrev && !$self->isexpanded() && $lrev != $self;
  return $self->{'data'}->{'rev'};
}

sub resolved {
  my ($self, $status) = @_;
  $self->{'data'}->{'resolved'} = 1 if $status;
  return $self->{'data'}->{'resolved'};
}

sub idx {
  my ($self) = @_;
  my $lrev = $self->localrev();
  return $self->{'data'}->{'idx'} if !$lrev || $lrev == $self;
  return $lrev->idx();
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
    return $self->targetrev()->satisfies(@constraints);
  }
  return 1;
}

sub constraints {
  my ($self, @constraints) = @_;
  my $data = $self->{'data'};
  push @{$data->{'constraints'}}, @constraints;
  $data->{'targetrev'}->constraints(@constraints) if $data->{'targetrev'};
  return @{$data->{'constraints'}};
}

sub revmgr {
  my ($self) = @_;
  return $self->{'data'}->{'revmgr'};
}

sub files {
  my ($self) = @_;
  return $self->revmgr()->lsrev($self);
}

sub file {
  my ($self, $filename) = @_;
  return $self->revmgr()->repfilename($self, $filename);
}

sub cookie {
  my ($self) = @_;
  die("rev has to be resolved\n") unless $self->resolved();
  return $self->{'data'}->{'cookie'} if $self->{'data'}->{'cookie'};
  my $cookie = $self->project() . '/' . $self->package;
  $cookie .= '/' . $self->localrev()->intrev()->{'rev'};
  # idx is needed in the future if we support deleted revisions...
  $cookie .= '/' . $self->localrev()->idx();
  if ($self->isexpanded()) {
    $cookie .= "\n" . $self->targetrev()->cookie();
  }
  print Dumper($cookie);
  $self->{'data'}->{'cookie'} = Digest::MD5::md5_hex($cookie);
  return $self->{'data'}->{'cookie'};
}

1;
