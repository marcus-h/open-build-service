package BSBlame::Blamer;

use strict;
use warnings;

use Data::Dumper;

use BSSrcBlame;

sub new {
  my ($class, $rev) = @_;
  my $self = {'rev' => $rev};
  bless $self, $class;
  $self->setupdeps_expanded() if $rev->isexpanded();
  $self->setupdeps_branch() if $rev->isbranch();
  $self->setupdeps_plain() if $rev->isplain();
  die("plain link not supported\n") if $rev->islink() && !$rev->isbranch();
  return $self;
}

sub setupdeps_expanded {
  my ($self) = @_;
  die("plain links are not yet supported\n")
    unless $self->{'rev'}->localrev()->isbranch();
  push @{$self->{'deps'}}, $self->{'rev'}->targetrev();
  push @{$self->{'deps'}}, $self->{'rev'}->localrev()->targetrev();
  push @{$self->{'deps'}}, $self->{'rev'}->localrev();
}

sub setupdeps_branch {
  my ($self) = @_;
  push @{$self->{'deps'}}, $self->{'rev'}->targetrev();
  my $range = $self->{'rev'}->revmgr()->range($self->{'rev'});
  my $plrev = $range->pred($self->{'rev'});
  return unless $plrev;
  push @{$self->{'deps'}}, $plrev->targetrev();
  push @{$self->{'deps'}}, $plrev;
}

sub setupdeps_plain {
  my ($self) = @_;
  my $range = $self->{'rev'}->revmgr()->range($self->{'rev'});
  my $prev = $range->pred($self->{'rev'});
  push @{$self->{'deps'}}, $prev if $prev;
}

sub hasconflict {
  my ($self) = @_;
  return 0 if $self->{'rev'}->isplain() || $self->{'rev'}->isexpanded();
  return $self->{'conflict'} if exists $self->{'conflict'};
  # need to check this only for a branch (or a link...)
  my $revmgr = $self->{'rev'}->revmgr();
  my $rev = $revmgr->expand($self->{'rev'}, $self->{'deps'}->[0]);
  $self->{'conflict'} = !defined($rev);
  return $self->{'conflict'};
}

sub deps {
  my ($self) = @_;
  return $self->{'deps'} || [];
}

sub lastworking {
  my ($self, $rev) = @_;
  $self->{'lastworking'} = $rev;
}

sub ready {
  my ($self, $filename) = @_;
  return 1 if $self->{'rev'}->blamedata($filename);
  return !grep {!$_->blamedata($filename)} @{$self->{'deps'}};
}

sub blame {
  my ($self, $filename) = @_;
  die("deps not blamed\n") unless $self->ready($filename);
  my $rev = $self->{'rev'};
  return $rev->blamedata($filename) if $rev->blamedata($filename);
  my $blamedata;
  $blamedata = $self->blame_expanded($filename) if $rev->isexpanded();
  $blamedata = $self->blame_branch($filename) if $rev->isbranch();
  $blamedata = $self->blame_plain($filename) if $rev->isplain();
  die("plain link not supported\n") if $rev->islink() && !$rev->isbranch();
  die("XXX\n") unless $blamedata;
  $rev->blamedata($filename, $blamedata);
  return $blamedata;
}

sub blame_expanded {
  my ($self, $filename) = @_;
  print "blame expanded\n";
  my $rev = $self->{'rev'};
  my $lrev = $rev->localrev();
  my $trev = $rev->targetrev();
  my $brev = $rev->localrev()->targetrev();
  return $self->calcblame($filename, $lrev, $trev, $brev);
}

sub blame_branch {
  my ($self, $filename) = @_;
  print "blame branch\n";
  die("TODO: conflict blame\n") if $self->hasconflict();
  my ($brev, $pbrev, $plrev) = @{$self->{'deps'}};
  # no predecessor => start of a branch, hence, just take the baserev's
  # blamedata (assumption: no keepcontent case branch)
  return $brev->blamedata($filename) unless $plrev;
  # calculate blame for last working expanded predecessor
  my $pblame = $self->calcblame($filename, $plrev, $brev, $pbrev);
  # next diff my rev against its last working expanded predecessor:
  # 2-way diff: diff prev lrev
  my $lrev = $self->{'rev'};
  my $prev = $lrev->revmgr()->expand($plrev, $brev, 1);
  $prev->blamedata($filename, $pblame);
  return $self->calcblame($filename, $prev, $lrev, $prev);
}

sub blame_plain {
  my ($self, $filename) = @_;
  print "blame plain\n";
  my $lrev = $self->{'rev'};
  # if lrev is the first rev in the range, plrev is undefined
  my $plrev = $self->{'deps'}->[0];
  print "plrev: " . ($plrev ? $plrev->intrev()->{'rev'} : 'undef') . "\n";
  # 2-way diff of myrev against its predecessor
  return $self->calcblame($filename, $plrev, $lrev, $plrev);
}

# could be static, but this way subclasses can override it
sub calcblame {
  my ($self, $filename, $myrev, $yourrev, $commonrev) = @_;
  my @blames = (
    $myrev ? $myrev->blamedata($filename) : undef,
    $yourrev ? $yourrev->blamedata($filename) : undef,
    $commonrev ? $commonrev->blamedata($filename) : undef
  );
  # XXX: add cnumlines
  my @blame;
  if ($yourrev && $commonrev) {
    @blame = BSSrcBlame::merge($myrev->file($filename) || '/dev/null',
                               $yourrev->file($filename) || '/dev/null',
                               $commonrev->file($filename)
                                 || '/dev/null',
                               scalar(@{$commonrev->blamedata($filename)}) - 1);
    print Dumper(\@blame);
  } else {
    @blame = BSSrcBlame::merge($yourrev->file($filename) || '/dev/null',
                               '/dev/null', '/dev/null');
  }
  # indicates that the file was removed (see also t/01-blame.t)
  @blame = () if @blame == 1 && $blame[0]->[1] == -1;
#  die("blame conflict (logic error)\n") unless defined($blame);
  return [map {$blames[$_->[0]] ? $blames[$_->[0]]->[$_->[1]] : $yourrev} @blame];
}

1;
