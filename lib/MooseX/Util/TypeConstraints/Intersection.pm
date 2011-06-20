use strict;
use warnings;

package MooseX::Util::TypeConstraints::Intersection;

use Moose::Exporter;

use MooseX::Meta::TypeConstraint::Intersection;

use Moose::Util::TypeConstraints qw();

Moose::Exporter->setup_import_methods( as_is => [qw( intersection )] );

sub create_type_constraint_intersection {
  unshift @_, undef;
  goto \&create_named_type_constraint_intersection;
}

sub create_named_type_constraint_intersection {
  my $name = shift;
  my @type_constraint_names;
  if ( scalar @_ == 1 && _detect_type_constraint_intersection( $_[0] ) ) {
    @type_constraint_names = _parse_type_constraint_intersection( $_[0] );
  }
  else {
    @type_constraint_names = @_;
  }

  ( scalar @type_constraint_names >= 2 )
    || __PACKAGE__->_throw_error("You must pass in at least 2 type names to make an intersection");

  my @type_constraints = map {
    Moose::Util::TypeConstraints::find_or_parse_type_constraint($_)
      || __PACKAGE__->_throw_error("Could not locate type constraint ($_) for the intersection");
  } @type_constraint_names;

  my %options = ( type_constraints => \@type_constraints, );
  $options{name} = $name if defined $name;
  return MooseX::Meta::TypeConstraint::Intersection->new(%options);
}

{

  # Stolen from Moose::Util::TypeConstraints
  # Not acessible to re-use
  #
  use re "eval";

  my $valid_chars     = qr{[\w:\.]};
  my $type_atom       = qr{ (?>$valid_chars+) }x;
  my $ws              = qr{ (?>\s*) }x;
  my $op_union        = qr{ $ws \| $ws }x;
  my $op_intersection = qr{ $ws & $ws }x;

  my ( $type, $type_capture_parts, $type_with_parameter, $union, $any, $intersection );
  if (Class::MOP::IS_RUNNING_ON_5_10) {
    my $type_pattern                = q{  (?&type_atom)  (?: \[ (?&ws)  (?&any)  (?&ws) \] )? };
    my $type_capture_parts_pattern  = q{ ((?&type_atom)) (?: \[ (?&ws) ((?&any)) (?&ws) \] )? };
    my $type_with_parameter_pattern = q{  (?&type_atom)      \[ (?&ws)  (?&any)  (?&ws) \]    };
    my $union_pattern               = q{ (?&type) (?> (?: (?&op_union) (?&type) )+ ) };
    my $intersection_pattern        = q{ (?&type) (?> (?: (?&op_intersection) (?&type) )+ )};
    my $any_pattern                 = q{ (?&type) | (?&union) | (?&intersection) };

    my $defines = qr{(?(DEFINE)
            (?<valid_chars>         $valid_chars)
            (?<type_atom>           $type_atom)
            (?<ws>                  $ws)
            (?<op_union>            $op_union)
            (?<op_intersection>     $op_intersection)
            (?<type>                $type_pattern)
            (?<type_capture_parts>  $type_capture_parts_pattern)
            (?<type_with_parameter> $type_with_parameter_pattern)
            (?<union>               $union_pattern)
            (?<intersection>        $intersection_pattern)
            (?<any>                 $any_pattern)
        )}x;

    $type                = qr{ $type_pattern                $defines }x;
    $type_capture_parts  = qr{ $type_capture_parts_pattern  $defines }x;
    $type_with_parameter = qr{ $type_with_parameter_pattern $defines }x;
    $union               = qr{ $union_pattern               $defines }x;
    $intersection        = qr{ $intersection_pattern        $defines }x;
    $any                 = qr{ $any_pattern                 $defines }x;
  }
  else {
    $type                = qr{  $type_atom  (?: \[ $ws  (??{$any})  $ws \] )? }x;
    $type_capture_parts  = qr{ ($type_atom) (?: \[ $ws ((??{$any})) $ws \] )? }x;
    $type_with_parameter = qr{  $type_atom      \[ $ws  (??{$any})  $ws \]    }x;
    $union               = qr{ $type (?> (?: $op_union $type )+ ) }x;
    $intersection        = qr{ $type (?> (?: $op_intersection $type )+ ) }x;
    $any                 = qr{ $type | $union | $intersection }x;
  }
  ##
  # end stealing
  #

  sub _parse_type_constraint_intersection {
    { no warnings 'void'; $any; }    # lexical capture force.
    my $given = shift;
    my @rv;
    while ( $given =~ m{ \G (?: $op_intersection )? ($type) }gcx ) {
      push @rv => $1;
    }
    ( pos($given) eq length($given) )
      || __PACKAGE__->_throw_error(
      "'$given' didn't parse (parse-pos=" . pos($given) . "and str-length=" . length($given) . ")" );
    @rv;
  }

  sub _detect_type_constraint_intersection {
    { no warnings 'void'; $any; }    # lexical capture force.
    $_[0] =~ m{^ $type $op_intersection $type ( $op_intersection .* )? $}x;
  }

}

sub intersection {

  my ( $type_name, @constraints ) = @_;
  if ( ref $type_name eq 'ARRAY' ) {
    @constraints == 0
      || __PACKAGE__->_throw_error("union called with an array reference and additional arguments.");
    @constraints = @$type_name;
    $type_name   = undef;
  }
  if ( @constraints == 1 && ref $constraints[0] eq 'ARRAY' ) {
    @constraints = @{ $constraints[0] };
  }
  if ( defined $type_name ) {
    return Moose::Util::TypeConstraints::register_type_constraint(
      create_named_type_constraint_intersection( $type_name, @constraints ) );
  }

  return create_type_constraint_intersection(@constraints);

}

1;

