package BSBlame::Iterator;

use strict;
use warnings;

use Data::Dumper;

sub new {
  my ($class, $data, @constraints) = @_;
  return bless {
    'data' => $data,
    'constraints' => \@constraints,
    'cur' => -1
  }, $class;
}

sub next {
  my ($self, @constraints) = @_;
  push @constraints, @{$self->{'constraints'}};
  my $i = \$self->{'cur'};
  my $data = $self->{'data'};
  for ($$i++; $$i < @$data; $$i++) {
    return $data->[$$i] if $data->[$$i]->satisfies(@constraints);
  }
  # not needed (just to be explicit)
  return undef;
}

1;
