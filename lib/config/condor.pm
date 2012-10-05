# Config file for condor
use config_common;
use File::Spec;
use File::Basename;
#use xcropt;
use Cwd;
use File::Basename qw(basename);
my $myname = basename(__FILE__, '.pm');
$ENV{"CONDOR_CONFIG"} = "/opt/condor-7.2.2/etc/condor_config";
$ENV{"CONDOR_BIN"} = "/opt/condor-7.2.2/bin";
$jsconfig::jobsched_config{$myname} = {
    # commands
    qsub_command => "$ENV{XCRYPT}/lib/config/condor_submit",
    qdel_command => "$ENV{CONDOR_BIN}/condor_rm",
    qstat_command => "$ENV{CONDOR_BIN}/condor_q",
    # standard options
    jobscript_preamble => ['#!/bin/sh'],
	jobscript_workdir => sub { '.'; },
    jobscript_option_stage_in_files => sub {
		my @dummy = ();
	    return @dummy;
    },
    jobscript_option_stage_out_files => sub {
    	my @dummy = ();
	    return @dummy;
    },
    stage_in_files => sub{
    	my (@file_list) =@_;
    	my $staging_files = join(',', @file_list);
    	$ENV{XCR_INPUTFILE}= $staging_files;
    },
    stage_out_files => sub{
    	my (@file_list) =@_;
    	my $staging_files = join(',', @file_list);
    	$ENV{XCR_OUTPUTFILE}= $staging_file;
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
