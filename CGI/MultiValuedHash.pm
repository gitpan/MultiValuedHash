=head1 NAME

CGI::MultiValuedHash - Store and manipulate url-encoded data.

=cut

######################################################################

package CGI::MultiValuedHash;
require 5.004;

# Copyright (c) 1999-2001, Darren R. Duncan. All rights reserved. This module is
# free software; you can redistribute it and/or modify it under the same terms as
# Perl itself.  However, I do request that this copyright information remain
# attached to the file.  If you modify this module and redistribute a changed
# version then please attach a note listing the modifications.

use strict;
use vars qw($VERSION @ISA);
$VERSION = '1.03';

######################################################################

=head1 DEPENDENCIES

=head2 Perl Version

	5.004

=head2 Standard Modules

	I<none>

=head2 Nonstandard Modules

	Data::MultiValuedHash 1.03 (parent class)

=cut

######################################################################

use Data::MultiValuedHash 1.03;
@ISA = qw( Data::MultiValuedHash );

######################################################################

=head1 SYNOPSIS

	use CGI::MultiValuedHash;

	my $case_insensitive = 1;
	my $complementry_set = 1;

	my $params = CGI::MultiValuedHash->new( $case_insensitive, 
		$ENV{'HTTP_COOKIE'} || $ENV{'COOKIE'}, '; ', '&' );

	my $query_string = '';
	if( $ENV{'REQUEST_METHOD'} =~ /^(GET|HEAD)$/ ) {
		$query_string = $ENV{'QUERY_STRING'};
	} else {
		read( STDIN, $query_string, $ENV{'CONTENT_LENGTH'} );
	}
	$params->from_url_encoded_string( $query_string );
	$params->trim_bounding_whitespace();  # clean up user input

	foreach my $key ($params->keys()) {
		my @values = $params->fetch( $key );
		print "Field '$key' contains: '".join( "','", @values )."'\n";
	}

	my @record_list = ();

	open( FH, "+<guestbook.txt" ) or die "can't open file: $!\n";
	flock( FH, 2 );
	seek( FH, 0, 2 );
	$params->to_file( \*FH );
	seek( FH, 0, 0 );
	until( eof( FH ) ) {
		push( @record_list, CGI::MultiValuedHash->new( 
			$case_insensitive, \*FH ) );
	}
	flock( FH, 8 );
	close( FH );
		
	foreach my $record (@record_list) {
		print "\nSubmitted by:".$record->fetch_value( 'name' )."\n";
		print "\nTracking cookie:".$record->fetch_value( 'track' )."\n";
		my %Qs_and_As = $record->fetch_all( ['name', 'track'], $complementary_set );
		foreach my $key (keys %Qs_and_As) {
			my @values = @{$Qs_and_As{$key}};
			print "Question: '$key'\n";
			print "Answers: '".join( "','", @values )."'\n";
		}
	}

=head1 DESCRIPTION

This Perl 5 object class extends the functionality of Data::MultiValuedHash with
new methods that are especially useful in a CGI environment.  Please read the POD
for the latter to see what the preexisting features are.  New functionality
includes importing and exporting of url-encoded data.  This process is
customizable and can handle such formats as http query or cookie strings, or
newline-delimited text files.  Similarly, this class can import from or export to
a file stream.  Other new features include exporting to html-encoded hidden form
fields, for the purpose of having persistant form data that is too large for a
query string.  New manipulation features include trimming of whitespace from
values so that when users type only enter such the field reads as empty.  Useful
inherited features include optional case-insensitive keys and the ability to
export subsets of data when only some is needed (separate "other" form fields
from special ones that you previously used).

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

This class is a subclass of Data::MultiValuedHash and inherits all of the
latter's functionality and behaviour.  Please read the POD for the latter to see
how to use the preexisting methods.

=head1 FUNCTIONS AND METHODS

=head2 initialize([ CASE[, SOURCE[, *]] ])

This method overrides the like-named method in Data::MultiValuedHash by allowing 
more data types to be used for SOURCE; namely, it adds filehandles and 
url-encoded strings.  It is backwards compatible.

This method is used by B<new()> to set the initial properties of objects that it
creates.  Calling it yourself will empty the internal hash.  If you provide
arguments to this method then the first one, CASE, will initialize the
case-insensitivity attribute, and any subsequent arguments will provide initial
keys and values for the internal hash.  Nothing is returned.

The first optional argument CASE (scalar) specifies whether or not the new
object uses case-insensitive keys or not; the default value is false. This
attribute can not be changed later, except by calling the B<initialize()> method.

The second optional argument, SOURCE is used as initial keys and values for this
object.  If it is a Hash Ref (normal or of arrays), then the store_all( SOURCE )
method is called to handle it.  If the same argument is a MVH object, then its
keys and values are similarly given to store_all( SOURCE ).  If SOURCE is a valid
file handle then from_file( SOURCE, * ) is used.  Otherwise, the method
from_url_encoded_string( SOURCE, * ) is used.

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
		} elsif( ref($initializer) eq 'GLOB' ) {
			$self->from_file( $initializer, @_ );
		} else {
			$self->from_url_encoded_string( $initializer, @_ );
		}
	}
}

######################################################################

=head2 trim_bounding_whitespace()

This method cleans up all of this object's values by trimming any leading or
trailing whitespace.  The keys are left alone.  This would normally be done when
the object is representing user input from a form, including when they entered
nothing but whitespace, and the program should act like they left the field
empty.

=cut

######################################################################

sub trim_bounding_whitespace {
	my $self = shift( @_ );
	foreach my $ra_values (values %{$self->{$KEY_MAIN_HASH}}) {
		foreach my $value (@{$ra_values}) {
			$value =~ s/^\s+//;
			$value =~ s/\s+$//;
		}
	}
}

######################################################################

=head2 to_url_encoded_string([ DELIM[, VALSEP] ])

This method returns a scalar containing all of this object's keys and values
encoded in an url-escaped "query string" format.  The escaping format specifies
that any characters which aren't in [a-zA-Z0-9_ .-] are replaced with a triplet
containing a "%" followed by the two-hex-digit representation of the ascii value
for the character.  Also, any " " (space) is replaced with a "+".  Each key and
value pair is delimited by a "=".  If a key has multiple values, then there are
that many "key=value" pairs.  The optional argument, DELIM, is a scalar
specifying what to use as a delimiter between pairs.  This is "&" by default.  If
a "\n" is given for DELIM, the resulting string would be suitable for writing to
a file where each key=value pair is on a separate line.  The second optional
argument, VALSEP, is a scalar that specifies the delimiter between multiple
consecutive values which share a common key, and that key only appears once.  For
example, SOURCE could be "key1=val1&val2; key2=val3&val4", as is the case with
"cookie" strings (DELIM is "; " and VALSEP is "&") or "isindex" queries.

=cut

######################################################################

sub to_url_encoded_string {
	my $self = shift( @_ );
	my $rh_main_hash = $self->{$KEY_MAIN_HASH};
	my $delim_kvpair = shift( @_ ) || '&';
	my $delim_values = shift( @_ );
	my @result;

	foreach my $key (sort keys %{$rh_main_hash}) {
		my $key_enc = $key;
		$key_enc =~ s/([^\w .-])/'%'.sprintf("%2.2X",ord($1))/ge;
		$key_enc =~ tr/ /+/;

		my @values;

		foreach my $value (@{$rh_main_hash->{$key}}) {
			my $value_enc = $value;   # s/// on $value changes original
			$value_enc =~ s/([^\w .-])/'%'.sprintf("%2.2X",ord($1))/ge;
			$value_enc =~ tr/ /+/;

			push( @values, $value_enc );
		}

		push( @result, "$key_enc=".( 
			$delim_values ? join( $delim_values, @values ) :
			join( "$delim_kvpair$key_enc=", @values ) 
		) );
	}

	return( join( $delim_kvpair, @result ) );
}

######################################################################

=head2 from_url_encoded_string( SOURCE[, DELIM[, VALSEP]] )

This method takes a scalar, SOURCE, containing a set of keys and values encoded
in an url-escaped "query string" format, and adds them to this object.  The
escaping format specifies that any characters which aren't in [a-zA-Z0-9_ .-] are
replaced with a triplet containing a "%" followed by the two-hex-digit
representation of the ascii value for the character.  Also, any " " (space) is
replaced with a "+".  Each key and value pair is delimited by a "=".  If a key
has multiple values, then there are that many "key=value" pairs.  The first
optional argument, DELIM, is a scalar specifying what to use as a delimiter
between pairs. This is "&" by default.  If a "\n" is given for DELIM, the source
string was likely read from a file where each key=value pair is on a separate
line.  The second optional argument, VALSEP, is a scalar that specifies the
delimiter between multiple consecutive values which share a common key, and that
key only appears once.  For example, SOURCE could be "key1=val1&val2;
key2=val3&val4", as is the case with "cookie" strings (DELIM is "; " and VALSEP
is "&") or "isindex" queries.

=cut

######################################################################

sub from_url_encoded_string {
	my $self = shift( @_ );
	my $source_str = shift( @_ );
	my $delim_kvpair = shift( @_ ) || '&';
	my $delim_values = shift( @_ );
	my @source = split( $delim_kvpair, $source_str );

	my $rh_main_hash = $self->{$KEY_MAIN_HASH};
	my $case_inse = $self->{$KEY_CASE_INSE};

	foreach my $pair (@source) {
		my ($key, $values_str) = split( '=', $pair, 2 );
		next if( $key eq "" );

		$key =~ tr/+/ /;
		$key =~ s/%([0-9a-fA-F]{2})/pack("c",hex($1))/ge;
		$key = lc($key) if( $case_inse );
		$rh_main_hash->{$key} ||= [];

		my @values = $delim_values ? 
			split( $delim_values, $values_str ) : $values_str;

		foreach my $value (@values) {
			$value =~ tr/+/ /;
			$value =~ s/%([0-9a-fA-F]{2})/pack("c",hex($1))/ge;
		
			push( @{$rh_main_hash->{$key}}, $value );
		}
	}

	return( scalar( @source ) );
}

######################################################################

=head2 to_file( FH[, DELIM[, VALSEP[, REC_DELIM[, EMPTY]]]]] )

This method encodes all of this object's keys and values using the
to_url_encoded_string( DELIM, VALSEP ) method and writes it to the filehandle
provided in FH.  The optional argument REC_DELIM is a scalar value that will be
written to FH before this encoded object, and serves to delimit multiple encoded
objects of this class.  The default values for [DELIM, VALSEP, REC_DELIM] are
["\n", undef, "\n=\n"].  If the boolean argument EMPTY is true then this object
will be written to FH even if it is empty (has no keys), resulting in only a
REC_DELIM actually being written.  The default behaviour of false prevents this
from happening, so only objects containing data are output.  This method returns
1 on a successful write, 0 for an empty record that was skipped, and it returns
undef on a file-system error.

=cut

######################################################################

sub to_file {
	my ($self, $fh, $delim_kvpair, $delim_values, $delim_recs, $use_empty) = @_;

	ref( $fh ) eq 'GLOB' or return( undef );

	$delim_kvpair ||= "\n";
	$delim_values ||= undef;
	$delim_recs ||= "\n=\n";
	
	local $\ = undef;

	!$self->keys_count() and !$use_empty and return( 0 );

	my $record_str = 
		$self->to_url_encoded_string( $delim_kvpair, $delim_values );

	print $fh "$delim_recs$record_str" or return( undef );
	
	return( 1 );
}

######################################################################

=head2 from_file( FH[, DELIM[, VALSEP[, REC_DELIM[, EMPTY]]]]] )

This method adds keys and values to this object from an encoded record read from 
the filehandle provided in FH and parsed with from_url_encoded_string( ., DELIM,
VALSEP ).  The optional argument REC_DELIM is a scalar value that delimits
encoded records in the file stream. The default values for [DELIM, VALSEP,
REC_DELIM] are ["\n", undef, "\n=\n"].  If the boolean argument EMPTY is true
then this object will be initialized to empty (has no keys) if the record
delimiter is encountered in the file stream before any valid encoded record.  The
default behaviour of false prevents this from happening, so the file stream
continues to be read until a valid record is found.  This method returns 1 on a
successful read, 0 for an empty record that was kept (may be end-of-file), and it
returns undef on a file-system error.

=cut

######################################################################

sub from_file {
	my ($self, $fh, $delim_kvpair, $delim_values, $delim_recs, $use_empty) = @_;

	ref( $fh ) eq 'GLOB' or return( undef );

	$delim_kvpair ||= "\n";
	$delim_values ||= undef;
	$delim_recs ||= "\n=\n";

	local $/ = $delim_recs;

	GET_ANOTHER_REC: {
		eof( $fh ) and return( 0 );

		defined( my $record_str = <$fh> ) or return( undef );
	
		$self->from_url_encoded_string( 
			$record_str, $delim_kvpair, $delim_values );
	
		$self->keys_count() and return( 1 );
	
		$use_empty and return( 0 );
	
		redo GET_ANOTHER_REC;
	}
}

######################################################################

=head2 to_html_encoded_hidden_fields()

This method returns a scalar containing html text which defines a list of hidden
form fields whose names and values are all of this object's keys and values. 
Each list element looks like '<INPUT TYPE="hidden" NAME="key" VALUE="value">'. 
Where a key has multiple values, a hidden field is made for each value.  All keys
and values are html-escaped such that any occurances of [&,",<,>] are substitued
with [&amp;,&quot;,&gt;,&lt;].  In cases where this object was storing user input
that was submitted using 'post', this method can generate the content of a
self-referencing form, should the main program need to call itself.  It would
handle persistant data which is too big to put in a self-referencing query
string.

=cut

######################################################################

sub to_html_encoded_hidden_fields {
	my $self = shift( @_ );
	my $rh_main_hash = $self->{$KEY_MAIN_HASH};
	my @result;

	foreach my $key (sort keys %{$rh_main_hash}) {
		my $key_enc = $key;
		$key_enc =~ s/&/&amp;/g;
		$key_enc =~ s/\"/&quot;/g;
		$key_enc =~ s/>/&gt;/g;
		$key_enc =~ s/</&lt;/g;

		foreach my $value (@{$rh_main_hash->{$key}}) {
			my $value_enc = $value;   # s/// on $value changes original
			$value_enc =~ s/&/&amp;/g;
			$value_enc =~ s/\"/&quot;/g;
			$value_enc =~ s/>/&gt;/g;
			$value_enc =~ s/</&lt;/g;

			push( @result, <<__endquote );
<INPUT TYPE="hidden" NAME="$key_enc" VALUE="$value_enc">
__endquote
		}
	}

	return( join( '', @result ) );
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

perl(1), Data::MultiValuedHash.

=cut
