=head1 NAME

Data::MultiValuedHash - Hash whose keys can have multiple ordered values.

=cut

######################################################################

package Data::MultiValuedHash;
require 5.004;

# Copyright (c) 1999-2001, Darren R. Duncan. All rights reserved. This module is
# free software; you can redistribute it and/or modify it under the same terms as
# Perl itself.  However, I do request that this copyright information remain
# attached to the file.  If you modify this module and redistribute a changed
# version then please attach a note listing the modifications.

use strict;
use vars qw($VERSION);
$VERSION = '1.03';

######################################################################

=head1 DEPENDENCIES

=head2 Perl Version

	5.004

=head2 Standard Modules

	I<none>

=head2 Nonstandard Modules

	I<none>

=head1 SYNOPSIS

	use Data::MultiValuedHash;

	$mvh = Data::MultiValuedHash->new();  # make empty, case-sensitive (norm)
	$mvh = Data::MultiValuedHash->new( 1 );  # make empty, case-insensitive
	$mvh = Data::MultiValuedHash->new( 0, {
		name => 'John',
		age => 17,
		color => 'green',
		siblings => ['Laura', 'Andrew', 'Julia'],
		pets => ['Cat', 'Bird'],
	} );  # make new with initial values, case-sensitive keys
	
	$mvh->store( age => 18 );  # celebrate a birthday
	
	$mvh->push( siblings => 'Tandy' );  # add a family member, returns 4
	
	$mvh->unshift( pets => ['Dog', 'Hamster'] );  # more pets
	
	$does_it = $mvh->exists( 'color' );  # returns true
	
	$name = $mvh->fetch_value( 'siblings' );  # returns 'Laura'
	$name = $mvh->fetch_value( 'siblings', 2 );  # returns 'Julia'
	$name = $mvh->fetch_value( 'siblings', -1 );  # returns 'Tandy'
	$rname = $mvh->fetch( 'siblings' );  # returns all 4 in array ref
	@names = $mvh->fetch( 'siblings' );  # returns all 4 as list
	
	$name = $mvh->fetch_value( 'Siblings' );  # returns nothing, wrong case
	$mv2 = Data::MultiValuedHash->new( 1, $mvh );  # conv to case inse
	$name = $mv2->fetch_value( 'Siblings' );  # returns 'Laura' this time
	$is_it = $mvh->ignores_case();  # returns false; like normal hashes
	$is_it = $mv2->ignores_case();  # returns true
	
	$color = $mvh->shift( 'color' );  # returns 'green'; none remain
	
	$animal = $mvh->pop( 'pets' );  # returns 'Bird'; three remain
	
	%list = $mvh->fetch_all();  # want all keys, all values
		# returns ( name => ['John'], age => [18], color => [], 
		# siblings => ['Laura', 'Andrew', 'Julia', 'Tandy'], 
		# pets => ['Dog', 'Hamster', 'Cat'] )
	
	%list = $mvh->fetch_first();  # want all keys, first values of each
		# returns ( name => 'John', age => 18, color => undef, 
		# siblings => 'Laura', pets => 'Dog' )
	
	%list = $mvh->fetch_last();  # want all keys, last values of each
		# returns ( name => 'John', age => 18, color => undef, 
		# siblings => 'Tandy', pets => 'Cat' )
	
	%list = $mvh->fetch_last( ['name', 'siblings'] );  # want named keys only
		# returns ( name => 'John', siblings => 'Tandy' )
	
	%list = $mvh->fetch_last( ['name', 'siblings'], 1 );  # want complement
		# returns ( age => 18, color => undef, pets => 'Cat' )
	
	$mv3 = $mvh->clone();  # make a duplicate of myself
	$mv4 = $mvh->clone( 'pets', 1 );  # leave out the pets in this "clone"
	
	@list = $mv3->keys();
		# returns ('name','age','color','siblings','pets')
	$num = $mv3->keys();  # whoops, doesn't do what we expect; returns array ref
	$num = $mv3->keys_count();  # returns 5
	
	@list = $mv3->values();
		# returns ( 'John', 18, 'Laura', 'Andrew', 'Julia', 'Tandy', 
		# 'Dog', 'Hamster', 'Cat' )
	@num = $mv3->values_count();  # returns 9
	
	$mv3->store_all( {
		songs => ['this', 'that', 'and the other'],
		pets => 'Fish',
	} );  # adds key 'songs' with values, replaces list of pets with 'fish'
	
	$mv3->store_value( 'pets', 'turtle' );  # replaces 'fish' with 'turtle'
	$mv3->store_value( 'pets', 'rabbit', 1 );  # pets is now ['turtle','rabbit']
	
	$oldval = $mv3->delete( 'color' );  # gets rid of color for good
	$rdump = $mv3->delete_all();  # return everything as hash of arrays, clear
	
=head1 DESCRIPTION

This Perl 5 object class implements a simple data structure that is similar to a
hash except that each key can have several values instead of just one.  There are
many places that such a structure is useful, such as database records whose
fields may be multi-valued, or when parsing results of an html form that contains
several fields with the same name.  This class can export a wide variety of
key/value subsets of its data when only some keys are needed.

While you could do tasks similar to this class by making your own hash with array
refs for values, you will need to repeat some messy-looking code everywhere you
need to use that data, creating a lot of redundant access or parsing code and 
increasing the risk of introducing errors.

One optional feature that this class provides is case-insensitive keys. 
Case-insensitivity simplifies matching form field names whose case may have been
changed by the web browser while in transit (I have seen it happen).  

=cut

######################################################################

# Names of properties for objects of this class are declared here:
my $KEY_MAIN_HASH = 'main_hash';  # this is a hash of arrays
my $KEY_CASE_INSE = 'case_inse';  # are our keys case insensitive?

######################################################################

=head1 SYNTAX

This class does not export any functions or methods, so you need to call them
using object notation.  This means using B<Class-E<gt>function()> for functions
and B<$object-E<gt>method()> for methods.  If you are inheriting this class for
your own modules, then that often means something like B<$self-E<gt>method()>. 

All method arguments and results are passed by value (where appropriate) such
that subsequent editing of them will not change values internal to the MVH
object; this is the generally accepted behaviour.

Most methods take either KEY or VALUES arguments.  KEYs are always treated as
scalars and VALUES are taken as a list.  Value lists can be passed either as an
ARRAY ref, whereupon they are internally flattened, or as an ordinary LIST.  If
the first VALUES argument is an ARRAY ref, it is interpreted as being the entire
list and subsequent arguments are ignored.  If you want to store an actual ARRAY
ref as a value, make sure to put it inside another ARRAY ref first, or it will be
flattened.

Any method which returns a list will check if it is being called in scalar or
list context.  If the context wants a scalar then the method returns its list in
an ARRAY ref; otherwise, the list is returned as a list.  This behaviour is the
same whether the returned list is an associative list (hash) or an ordinary list
(array).  Failures are returned as "undef" in scalar context and "()" in list
context.  Scalar results are returned as themselves, of course.

When case-insensitivity is used, all operations involving hash keys operate with
lowercased versions, and these are also what is stored.  The default setting of
the "ignores case" property is false, like with a normal hash, and can only be
set when the object is reinitialized; changing this setting at other times could
cause problems where keys no longer match that used to.

=head1 FUNCTIONS AND METHODS

=head2 new([ CASE[, SOURCE] ])

This function creates a new Data::MultiValuedHash (or subclass) object and
returns it.  All of the method arguments are passed to initialize() as is; please
see the POD for that method for an explanation of them.

=cut

######################################################################

sub new {
	my $class = shift( @_ );
	my $self = bless( {}, ref($class) || $class );
	$self->initialize( @_ );
	return( $self );
}

######################################################################

=head2 initialize([ CASE[, SOURCE] ])

This method is used by B<new()> to set the initial properties of objects that it
creates.  Calling it yourself will empty the internal hash.  If you provide
arguments to this method then the first one, CASE, will initialize the
case-insensitivity attribute, and any subsequent arguments will provide initial
keys and values for the internal hash.  Nothing is returned.

The first optional argument CASE (scalar) specifies whether this object uses
case-insensitive keys; the default value is false.  This attribute can not be
changed later, except by calling the B<initialize()> method.

The second optional argument, SOURCE is used as initial keys and values for this
object.  If it is a Hash Ref (normal or of arrays), then the store_all( SOURCE )
method is called to handle it.  If the same argument is a MVH object, then its
keys and values are similarly given to store_all( SOURCE ).  Otherwise, SOURCE 
is ignored and this object starts off empty.

=cut

######################################################################

sub initialize {
	my $self = shift( @_ );
	$self->{$KEY_MAIN_HASH} = {};
	if( scalar( @_ ) ) {	
		$self->{$KEY_CASE_INSE} = shift( @_ );
		my $initializer = shift( @_ );
		if( UNIVERSAL::isa($initializer,'Data::MultiValuedHash') or 
				ref($initializer) eq 'HASH' ) {
			$self->store_all( $initializer );
		}
	}
}

######################################################################

=head2 clone([ CLONE[, KEYS[, COMPLEMENT]] ])

This method initializes a new object to have all of the same properties of the
current object and returns it.  This new object can be provided in the optional
argument CLONE (if CLONE is an object of the same class as the current object);
otherwise, a brand new object of the current class is used.  Only object
properties recognized by Data::MultiValuedHash are set in the clone; other
properties are not changed.  If the optional arguments KEYS and COMPLEMENT are
used, then the clone may not have all the keys that the parent does.  KEYS is an
array ref that specifies a subset of all this object's keys that we want
returned.  If the boolean COMPLEMENT is true, then the complement of the keys
listed in KEYS is returned instead.

=cut

######################################################################

sub clone {
	my ($self, $clone, @args) = @_;
	ref($clone) eq ref($self) or $clone = bless( {}, ref($self) );

	my $rh_main_hash = $self->{$KEY_MAIN_HASH};
	my %hash_copy = 
		map { ( $_, [@{$rh_main_hash->{$_}}] ) } keys %{$rh_main_hash};
	if( $args[0] ) {
		$self->_reduce_hash_to_subset( \%hash_copy, @args );
	}

	$clone->{$KEY_MAIN_HASH} = \%hash_copy;
	$clone->{$KEY_CASE_INSE} = $self->{$KEY_CASE_INSE};
	
	return( $clone );
}

######################################################################

=head2 ignores_case()

This method returns true if this object uses case-insensitive keys.

=cut

######################################################################

sub ignores_case {
	my $self = shift( @_ );
	return( $self->{$KEY_CASE_INSE} );
}

######################################################################

=head2 keys()

This method returns a list of all this object's keys.

=cut

######################################################################

sub keys {
	my $self = shift( @_ );
	my @keys_list = keys %{$self->{$KEY_MAIN_HASH}};
	return( wantarray ? @keys_list : \@keys_list );
}

######################################################################

=head2 keys_count()

This method returns a count of this object's keys.

=cut

######################################################################

sub keys_count {
	my $self = shift( @_ );
	return( scalar( keys %{$self->{$KEY_MAIN_HASH}} ) );
}

######################################################################

=head2 values()

This method returns a flattened list of all this object's values.

=cut

######################################################################

sub values {
	my $self = shift( @_ );
	my @values_list = map { @{$_} } values %{$self->{$KEY_MAIN_HASH}};
	return( wantarray ? @values_list : \@values_list );
}

######################################################################

=head2 values_count()

This method returns a count of all this object's values.

=cut

######################################################################

sub values_count {
	my $self = shift( @_ );
	my $count = 0;
	map { $count += scalar( @{$_} ) } values %{$self->{$KEY_MAIN_HASH}};
	return( $count );
}

######################################################################

=head2 exists( KEY )

This method returns true if KEY is in the hash, although it may not have any
values.

=cut

######################################################################

sub exists {
	my $self = shift( @_ );
	my $key = $self->{$KEY_CASE_INSE} ? lc(shift( @_ )) : shift( @_ );
	return( exists( $self->{$KEY_MAIN_HASH}->{$key} ) );
}

######################################################################

=head2 count( KEY )

This method returns a count of the values that KEY has.  It returns failure if
KEY doesn't exist.

=cut

######################################################################

sub count {
	my $self = shift( @_ );
	my $key = $self->{$KEY_CASE_INSE} ? lc(shift( @_ )) : shift( @_ );
	my $ra_values = $self->{$KEY_MAIN_HASH}->{$key};
	return( defined( $ra_values ) ? scalar( @{$ra_values} ) : undef );
}

######################################################################

=head2 fetch( KEY )

This method returns a list of all values that KEY has.  It returns failure if KEY
doesn't exist.

=cut

######################################################################

sub fetch {
	my $self = shift( @_ );
	my $key = $self->{$KEY_CASE_INSE} ? lc(shift( @_ )) : shift( @_ );
	my $ra_values = $self->{$KEY_MAIN_HASH}->{$key} or return;
	return( wantarray ? @{$ra_values} : [@{$ra_values}] );
}

######################################################################

=head2 fetch_value( KEY[, INDEX] )

This method returns a single value of KEY, which is at INDEX position in the
internal array of values; the default INDEX is 0.  It returns failure if KEY
doesn't exist.

=cut

######################################################################

sub fetch_value {
	my $self = shift( @_ );
	my $key = $self->{$KEY_CASE_INSE} ? lc(shift( @_ )) : shift( @_ );
	my $index = shift( @_ ) || 0;
	my $ra_values = $self->{$KEY_MAIN_HASH}->{$key} or return;
	return( $ra_values->[$index] );
}

######################################################################

=head2 fetch_first([ KEYS[, COMPLEMENT] ])

This method returns a hash with all this object's keys, but only the first value
for each key.  The first optional argument, KEYS, is an array ref that specifies
a subset of all this object's keys that we want returned. If the second optional
boolean argument, COMPLEMENT, is true, then the complement of the keys listed in
KEYS is returned instead.

=cut

######################################################################

sub fetch_first {
	my $self = shift( @_ );
	my $rh_main_hash = $self->{$KEY_MAIN_HASH};
	my %hash_copy = 
		map { ( $_, $rh_main_hash->{$_}->[0] ) } keys %{$rh_main_hash};
	if( $_[0] ) {
		$self->_reduce_hash_to_subset( \%hash_copy, @_ );
	}
	return( wantarray ? %hash_copy : \%hash_copy );
}

######################################################################

=head2 fetch_last([ KEYS[, COMPLEMENT] ])

This method returns a hash with all this object's keys, but only the last value
for each key.  The first optional argument, KEYS, is an array ref that specifies
a subset of all this object's keys that we want returned. If the second optional
boolean argument, COMPLEMENT, is true, then the complement of the keys listed in
KEYS is returned instead.

=cut

######################################################################

sub fetch_last {
	my $self = shift( @_ );
	my $rh_main_hash = $self->{$KEY_MAIN_HASH};
	my %hash_copy = 
		map { ( $_, $rh_main_hash->{$_}->[-1] ) } keys %{$rh_main_hash};
	if( $_[0] ) {
		$self->_reduce_hash_to_subset( \%hash_copy, @_ );
	}
	return( wantarray ? %hash_copy : \%hash_copy );
}

######################################################################

=head2 fetch_all([ KEYS[, COMPLEMENT] ])

This method returns a hash with all this object's keys and values.  The values
for each key are contained in an ARRAY ref.  The first optional argument, KEYS,
is an array ref that specifies a subset of all this object's keys that we want
returned.  If the second optional boolean argument, COMPLEMENT, is true, then the
complement of the keys listed in KEYS is returned instead.

=cut

######################################################################

sub fetch_all {
	my $self = shift( @_ );
	my $rh_main_hash = $self->{$KEY_MAIN_HASH};
	my %hash_copy = 
		map { ( $_, [@{$rh_main_hash->{$_}}] ) } keys %{$rh_main_hash};
	if( $_[0] ) {
		$self->_reduce_hash_to_subset( \%hash_copy, @_ );
	}
	return( wantarray ? %hash_copy : \%hash_copy );
}

######################################################################

=head2 store( KEY, VALUES )

This method adds a new KEY to this object, if it doesn't already exist. The
VALUES replace any that may have existed before.  This method returns the new
count of values that KEY has.  The best way to get a key which has no values is
to pass an empty ARRAY ref as the VALUES.

=cut

######################################################################

sub store {
	my $self = shift( @_ );
	my $key = $self->{$KEY_CASE_INSE} ? lc(shift( @_ )) : shift( @_ );
	my $ra_values = (ref( $_[0] ) eq 'ARRAY') ? shift( @_ ) : \@_;
	$self->{$KEY_MAIN_HASH}->{$key} = [@{$ra_values}];
	return( scalar( @{$self->{$KEY_MAIN_HASH}->{$key}} ) );
}

######################################################################

=head2 store_value( KEY, VALUE[, INDEX] )

This method adds a new KEY to this object, if it doesn't already exist.  The 
VALUE replaces any that may have existed before at INDEX position in the 
internal array of values; the default INDEX is 0.  This method returns the new 
count of values that KEY has, which may be more than one greater than before.

=cut

######################################################################

sub store_value {
	my $self = shift( @_ );
	my $key = $self->{$KEY_CASE_INSE} ? lc(shift( @_ )) : shift( @_ );
	my $value = shift( @_ );
	my $index = shift( @_ ) || 0;
	$self->{$KEY_MAIN_HASH}->{$key} ||= [];
	$self->{$KEY_MAIN_HASH}->{$key}->[$index] = $value;
	return( scalar( @{$self->{$KEY_MAIN_HASH}->{$key}} ) );
}

######################################################################

=head2 store_all( SOURCE )

This method takes one argument, SOURCE, which is an associative list or hash ref
or MVH object containing new keys and values to store in this object.  The value
associated with each key can be either scalar or an array.  Symantics are the
same as for calling store() multiple times, once for each KEY. Existing keys and
values with the same names are replaced.

=cut

######################################################################

sub store_all {
	my $self = shift( @_ );
	my %new = UNIVERSAL::isa( $_[0], 'Data::MultiValuedHash' ) ? 
		(%{shift( @_ )->{$KEY_MAIN_HASH}}) : 
		(ref( $_[0] ) eq 'HASH') ? (%{shift( @_ )}) : @_;
	my $rh_main_hash = $self->{$KEY_MAIN_HASH};
	my $case_inse = $self->{$KEY_CASE_INSE};
	foreach my $key (keys %new) {
		$key = lc($key) if( $case_inse );
		my $ra_values = (ref($new{$key}) eq 'ARRAY') ? 
			[@{$new{$key}}] : [$new{$key}];
		$rh_main_hash->{$key} = $ra_values;
	}
	return( scalar( keys %new ) );
}

######################################################################

=head2 push( KEY, VALUES )

This method adds a new KEY to this object, if it doesn't already exist. The
VALUES are appended to the list of any that existed before.  This method returns
the new count of values that KEY has.

=cut

######################################################################

sub push {
	my $self = shift( @_ );
	my $key = $self->{$KEY_CASE_INSE} ? lc(shift( @_ )) : shift( @_ );
	my $ra_values = (ref( $_[0] ) eq 'ARRAY') ? shift( @_ ) : \@_;
	$self->{$KEY_MAIN_HASH}->{$key} ||= [];
	push( @{$self->{$KEY_MAIN_HASH}->{$key}}, @{$ra_values} );
	return( scalar( @{$self->{$KEY_MAIN_HASH}->{$key}} ) );
}

######################################################################

=head2 unshift( KEY, VALUES )

This method adds a new KEY to this object, if it doesn't already exist. The
VALUES are prepended to the list of any that existed before.  This method returns
the new count of values that KEY has.

=cut

######################################################################

sub unshift {
	my $self = shift( @_ );
	my $key = $self->{$KEY_CASE_INSE} ? lc(shift( @_ )) : shift( @_ );
	my $ra_values = (ref( $_[0] ) eq 'ARRAY') ? shift( @_ ) : \@_;
	$self->{$KEY_MAIN_HASH}->{$key} ||= [];
	unshift( @{$self->{$KEY_MAIN_HASH}->{$key}}, @{$ra_values} );
	return( scalar( @{$self->{$KEY_MAIN_HASH}->{$key}} ) );
}

######################################################################

=head2 pop( KEY )

This method removes the last value associated with KEY and returns it.  It
returns failure if KEY doesn't exist.

=cut

######################################################################

sub pop {
	my $self = shift( @_ );
	my $key = $self->{$KEY_CASE_INSE} ? lc(shift( @_ )) : shift( @_ );
	return( exists( $self->{$KEY_MAIN_HASH}->{$key} ) ?
		pop( @{$self->{$KEY_MAIN_HASH}->{$key}} ) : undef );
}

######################################################################

=head2 shift( KEY )

This method removes the last value associated with KEY and returns it.  It
returns failure if KEY doesn't exist.

=cut

######################################################################

sub shift {
	my $self = shift( @_ );
	my $key = $self->{$KEY_CASE_INSE} ? lc(shift( @_ )) : shift( @_ );
	return( exists( $self->{$KEY_MAIN_HASH}->{$key} ) ?
		shift( @{$self->{$KEY_MAIN_HASH}->{$key}} ) : undef );
}

######################################################################

=head2 delete( KEY )

This method removes KEY and returns its values.  It returns failure if KEY
doesn't previously exist.

=cut

######################################################################

sub delete {
	my $self = shift( @_ );
	my $key = $self->{$KEY_CASE_INSE} ? lc(shift( @_ )) : shift( @_ );
	my $ra_values = delete( $self->{$KEY_MAIN_HASH}->{$key} );
	return( wantarray ? @{$ra_values} : $ra_values );
}

######################################################################

=head2 delete_all()

This method deletes all this object's keys and values and returns them in a hash.
 The values for each key are contained in an ARRAY ref.

=cut

######################################################################

sub delete_all {
	my $self = shift( @_ );
	my $rh_main_hash = $self->{$KEY_MAIN_HASH};
	$self->{$KEY_MAIN_HASH} = {};
	return( wantarray ? %{$rh_main_hash} : $rh_main_hash );
}

######################################################################

sub _reduce_hash_to_subset {    # meant only for internal use
	my $self = shift( @_ );
	my $rh_hash_copy = shift( @_ );
	my $ra_keys = shift( @_ );
	$ra_keys = (ref($ra_keys) eq 'HASH') ? (keys %{$ra_keys}) : 
		UNIVERSAL::isa($ra_keys,'Data::MultiValuedHash') ? $ra_keys->keys() : 
		(ref($ra_keys) ne 'ARRAY') ? [$ra_keys] : $ra_keys;
	my $case_inse = $self->{$KEY_CASE_INSE};
	my %spec_keys = 
		map { ( $case_inse ? lc($_) : $_ => 1 ) } @{$ra_keys};	
	if( shift( @_ ) ) {   # want complement of keys list
		%{$rh_hash_copy} = map { !$spec_keys{$_} ? 
			($_ => $rh_hash_copy->{$_}) : () } keys %{$rh_hash_copy};
	} else {
		%{$rh_hash_copy} = map { $spec_keys{$_} ? 
			($_ => $rh_hash_copy->{$_}) : () } keys %{$rh_hash_copy};
	}
}

######################################################################

1;
__END__

=head1 AUTHOR

Copyright (c) 1999-2001, Darren R. Duncan. All rights reserved. This module is
free software; you can redistribute it and/or modify it under the same terms as
Perl itself.  However, I do request that this copyright information remain
attached to the file.  If you modify this module and redistribute a changed
version then please attach a note listing the modifications.

I am always interested in knowing how my work helps others, so if you put this
module to use in any of your own code then please send me the URL. Also, if you
make modifications to the module because it doesn't work the way you need, please
send me a copy so that I can roll desirable changes into the main release.

Address comments, suggestions, and bug reports to B<perl@DarrenDuncan.net>.

=head1 CREDITS

Thanks to Johan Vromans <jvromans@squirrel.nl> for suggesting the split of my old
module "CGI::HashOfArrays" into the two current ones, "Data::MultiValuedHash" and
"CGI::MultiValuedHash".  This took care of a longstanding logistical problem
concerning whether the module was a generic data structure or a tool for
encoding/decoding CGI data.

Thanks to Steve Benson <steve.benson@stanford.edu> for suggesting POD
improvements in regards to the case-insensitivity feature, so the documentation
is easier to understand.

=head1 SEE ALSO

perl(1), CGI::MultiValuedHash.

=cut
