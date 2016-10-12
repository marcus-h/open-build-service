package BSBlame::Range;

use strict;
use warnings;

use Data::Dumper;

use BSBlame::Constraint;
use BSBlame::Iterator;

sub new {
  my ($class, $start, $data) = @_;
  return bless {
    'start' => $start,
    # don't even dare to modify data (we could also use a list but well...
    # this class behaves;) )
    'data' => $data
  }, $class;
}

sub end {
  my ($self, $end) = @_;
  die("illegal end\n") unless defined($end);
  my $oldend = $self->{'end'};
  $self->{'end'} = $end;
  return $oldend;
}

sub contains {
  my ($self, $rev) = @_;
  die("illegal rev\n") if !defined($rev) || $rev->isexpanded();
#  print $rev->{'data'}->{'rev'}->{'rev'} . "\n";
#  print $rev->idx() . "\n";
  return 0 unless $rev->idx() >= $self->{'start'};
  return 0 unless !defined($self->{'end'}) || $rev->idx() <= $self->{'end'};
  # representant of the whole range
  my $rrev = $self->{'data'}->[$self->{'start'}];
  return 0 unless $rrev->project() eq $rev->project();
  return 0 unless $rrev->package() eq $rev->package();
  for (qw(islink isbranch)) {
    return 0 if $rrev->$_() && !$rev->$_();
    return 0 if !$rrev->$_() && $rev->$_();
  }
  if ($rrev->islink()) {
    # TODO: plain link handling
    die("branches only\n") unless $rrev->isbranch();
    my $trrev = $rrev->targetrev();
    my $trev = $rev->targetrev();
    return 0 unless $trrev->project() eq $trev->project();
    return 0 unless $trrev->package() eq $trev->package();
  }
  return 1;
}

sub pred {
  my ($self, $rev) = @_;
  die("rev not in range\n") unless $self->contains($rev);
  return undef unless $rev->idx() < $self->{'end'};
  return $self->{'data'}->[$rev->idx() + 1];
}

sub iter {
  my ($self) = @_;
  my $start = $self->{'start'};
  my $end = $self->{'end'};
  die("inconsistent range state\n") unless defined($start) && defined($end);
  # hmm introduce special constraints such that we can pass
  # start and end as a reference (so that the iterator is consistent
  # after a range split)
  # TODO: testcase that demonstrates why we need non-global constraints here
  return BSBlame::Iterator->new($self->{'data'},
                                BSBlame::Constraint->new("idx >= $start", 0),
                                BSBlame::Constraint->new("idx <= $end", 0));
}

1;
