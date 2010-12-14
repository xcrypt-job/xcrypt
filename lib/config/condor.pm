# Config file for condor
use config_common;
use File::Spec;
use File::Basename;
#use xcropt;
use Cwd;
$jsconfig::jobsched_config{"condor"} = {
    # commands
    qsub_command => "$ENV{XCRYPT}/lib/config/condor_submit",
    qdel_command => "/opt/condor-7.2.2/bin/condor_rm",
    qstat_command => "/opt/condor-7.2.2/bin/condor_q",
    # standard options
    jobscript_preamble => ['#!/bin/sh'],
	jobscript_workdir => sub { '.'; },
#    jobscript_workdir => sub { '/home/xcryptuser/mount'; },
    jobscript_option_stage_in_files => sub {
		my @dummy = ();
	    return @dummy;
    },
    jobscript_option_stage_out_files => sub {
    	my @dummy = ();
	    return @dummy;
    },
    stage_in_files => sub{
    	my $self = shift;
    	$ENV{XCR_INPUTFILE}= $self;
    },
    stage_out_files => sub{
    	my $self = shift;
    	$ENV{XCR_OUTPUTFILE}= $self;
    },
    qsub_option_stdout => workdir_file_option('-o ', 'stdout'),
    qsub_option_stderr => workdir_file_option('-e ', 'stderr'),
    extract_req_id_from_qsub_output => sub {
        my (@lines) = @_;
        my $jobid = $lines[0];
		chomp $jobid;
		return $jobid;
    },
    extract_req_ids_from_qstat_output => sub {
        my (@lines) = @_;
        my @ids = ();
        foreach (@lines) {
            if ($_ =~ /^([0-9]+)/) {
                push (@ids, $1);
            }
        }
        return @ids;
    },
};
