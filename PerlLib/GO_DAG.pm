package GO_DAG;

use strict;
use warnings;
use Carp;

use FindBin;
use Data::Dumper;

my %DAG;

my $go_dag_singleton_obj = undef;


sub get_GO_DAG {
    
    return(GO_DAG->new());
}

sub dump_DAG {
    my $self = shift;

    foreach my $id (keys %DAG) {
        print "$id\t" . Dumper($DAG{$id});
    }
    
    return;
}



sub node_exists {
	my $self = shift;
	my ($id) = @_;
	
	if (exists $DAG{$id}) {
		return(1);
	}
	else {
		return(0);
	}
}

sub get_node {
	my $self = shift;
	my ($id) = @_;
	
	return($DAG{$id});
}


sub get_parent_ids {
	my $self = shift;
	my ($id) = @_;

	my $node = $DAG{$id};
	unless ($node) {
	    confess "Error, no node found for $id";
	}

	my @parents = $node->get_parents();
	
	return(@parents);
}

sub get_all_ids_in_path { ## includes submitted ids
	my $self = shift;
	my (@ids) = @_;

	my %ancestors;
	foreach my $id (@ids) {
		
		## include id in ancestor path
		$ancestors{$id}++;

		my @parents = $self->get_parent_ids($id);
		
		foreach my $parent (@parents) {
			$ancestors{$parent}++;
			my @ancestors = $self->get_all_ids_in_path($parent);
			foreach my $ancestor (@ancestors) {
				$ancestors{$ancestor}++;
			}
		}
	}

	my @ancestors = keys %ancestors;

	return(@ancestors);
}



####################
## Private methods
####################

sub new {
    my $packagename = shift;
    # print "PACKAGENAME: $packagename\n";
    
    unless ($go_dag_singleton_obj) {
        my $self = {};
        
        bless ($self, $packagename);
        &init_GO_DAG();
        $go_dag_singleton_obj = $self;
    }
    
    return($go_dag_singleton_obj);
    
}

sub init_GO_DAG {

    print STDERR "-init GO_DAG\n";
    
	my $obo_file = "obo/go-basic.obo.gz"; #gene_ontology.1_2.obo.gz";
    my ($obo_dir)  =  grep { -s "$_/$obo_file"  }  @INC;

	unless ($obo_dir) {
		confess "Error, cannot find $obo_file file in @INC";
	}
	
	my $obo = "$obo_dir/$obo_file";
	
	print STDERR "Found obo: $obo\n";

    my %term_info;    
    my $term_flag = 0;

    open (my $fh, "gunzip -c $obo | ") or confess "Error, cannot open file $obo";
    while (<$fh>) {
        
        unless (/\w/) { next; }
        #print $_;
        chomp;


        my $line = $_;
        
        if ($line =~ /^\[/) {
            #print STDERR "-got bracket\n";
            if ($term_info{id}) {
                &add_node(%term_info); # process previous term info
            }
            
            %term_info = (); # reinit
            $term_flag = 0;
            
            if ($line =~ /^\[Term\]/) {
                $term_flag = 1;
                #print STDERR "-term flag ON\n";
            }
            
        }
        elsif ($term_flag && $line =~ /^(\S+):\s+(.*)$/) {
            my $token = $1;
            my $descr = $2;
            
            push (@{$term_info{$token}}, $descr);
        }
    }
    close $fh;
    
    # get last one.
    if (%term_info) {
        &add_node(%term_info);
    }
    
    return;
}

####
sub add_node {
    my (%term_info) = @_;

    my $go_id = $term_info{id}->[0];
    my $name = $term_info{name}->[0];
    my $namespace = $term_info{namespace}->[0];
    my $def = $term_info{def}->[0];

    
	unless ($go_id) {
		# nothing to add.
		return;
	}

    my $node;

    eval {
        $node = GO_DAG::node->new($go_id, $name, $namespace, $def);
    };

    if ($@) {
        confess "Error, cannot create new GO node based on: " . Dumper(\%term_info);
    }
    
	
    if (exists $term_info{subset}) {
        $node->add_subsets(@{$term_info{subset}});
    }
	
    if (exists $term_info{is_a}) {
        $node->add_parents(@{$term_info{is_a}});
    }

    if (exists $term_info{synonym}) {
        $node->add_synonyms(@{$term_info{synonym}});
    }

    if (exists $term_info{xref}) {
        $node->add_xrefs(@{$term_info{xref}});
    }

    
    my @ids = ($go_id);
    if (exists $term_info{alt_id}) {
		
        my @alt_ids = @{$term_info{alt_id}};
        $node->add_alt_ids(@alt_ids);

		#print "-adding ALT_IDs: @alt_ids to $go_id\n";
		push (@ids, @alt_ids);
	}
    
    foreach my $id (@ids) {

        if (exists $DAG{$id}) {
			confess "Error, node already stored for id: $id";
        }
		
		$DAG{$id} = $node;
	}
    
    return($node);
    
}

package GO_DAG::node;

use strict;
use warnings;
use Carp qw (cluck croak confess);

sub new {
    my $packagename = shift;
    my ($go_id, $name, $namespace, $definition) = @_;

    unless ($go_id && $name && $namespace && $definition) {
        confess "Error, need params (go_id, name, namespace, definition)";
    }
    

    my $self = { 
        go_id => $go_id,
        name => $name,
        namespace => $namespace,
        definition => $definition,
        
        alt_id => [],
        subsets => [],
       
        synonyms => [],
        xrefs => [],
        
        parents => [],
        
        
   };

    bless ($self, $packagename);

    return($self);
    

}

sub add_subsets {
    my $self = shift;
    my @subsets = @_;

    push (@{$self->{subsets}}, @subsets);
 
    return;
}

sub get_subsets {
	my $self = shift;
	return(@{$self->{subsets}});
}

sub add_parents {
    my $self = shift;
    my @parents = @_;

	my @parent_go_ids;
	foreach my $parent (@parents) {
		if ($parent =~ /^(GO:\d+)/) {
			push (@parent_go_ids, $1);
		}
		elsif ($parent !~ /^\!/) {
            
		    print STDERR "Warning, cannot parse parent info: $parent\n";
		}
	}
    
	if (@parent_go_ids) {
		push (@{$self->{parents}}, @parent_go_ids);
	}
	
    return;
}

sub get_parents {
	my $self = shift;
	return (@{$self->{parents}});
}


sub add_synonyms {
    my $self = shift;
    my @synonyms = @_;

    push (@{$self->{synonyms}}, @synonyms);

    return;
}

sub get_synonyms {
	my $self = shift;
	return(@{$self->{synonyms}});
}

sub add_xrefs {
    my $self = shift;
    my @xrefs = @_;

    push (@{$self->{xrefs}}, @xrefs);
    
    return;
}

sub get_xrefs {
	my $self = shift;
	return(@{$self->{xrefs}});
}


sub add_alt_ids {
    my $self = shift;
    my @alt_ids = @_;

    push (@{$self->{alt_id}}, @alt_ids);

    return;
}

sub get_alt_ids {
	my $self = shift;
	return(@{$self->{alt_id}});
}


sub get_name {
	my $self = shift;
	return($self->{name});
}



1; #EOM


