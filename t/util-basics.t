use strict;
use warnings;

use Test::More;

use Moose::Util::TypeConstraints;
use MooseX::Util::TypeConstraints::Intersection;

subtype 'UnderTen', as 'Int', where { $_ < 10 };

subtype 'OverFive', as 'Int', where { $_ > 5 };

subtype 'NotSeven', as 'Int', where { $_ != 7 };

intersection 'TenToFive' => 'UnderTen&OverFive&NotSeven';

intersection 'TenToFiveB' => [ 'UnderTen', 'OverFive','NotSeven' ];

my $anonintersection = intersection(['UnderTen','OverFive', 'NotSeven']);

for my $typename (qw( TenToFive TenToFiveB ), $anonintersection) {
  my $type = Moose::Util::TypeConstraints::find_or_parse_type_constraint($typename);
  if ( not $type ) { fail("Not found $typename"); next }
  else {
    pass("Found $typename");
  }
  subtest "$typename tests" => sub {
    for my $i ( -10 .. 5 ) {
      ok( !$type->check($i), "Under 5 doesn't pass with $i" );
    }
    for my $i ( 6,8,9 ) {
      ok( $type->check($i), "6,8,9 passes with $i" );
    }
    for my $i ( 7 ) {
      ok( !$type->check($i), "7 doesn't pass" );
    }

    for my $i ( 10 .. 20 ) {
      ok( !$type->check($i), "Over 10 doesn't pass with $i" );
    }
  };
}

done_testing;

