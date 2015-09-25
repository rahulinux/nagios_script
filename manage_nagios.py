#!/usr/bin/env python

import sys
from pynag.Parsers import config
import pynag.Model
import docopt


usage = """
Usage:
   manage-nagios.py --add --env <environment> --host <fqdn> --groups <groups>
   manage-nagios.py --del --host <fqdn>
   manage-nagios.py (-h | --help)

Note: You can specify multiple group seperated by comma
"""



# nagios config file
nc = config('/etc/nagios/nagios.cfg')
nc.extended_parse()
nc.cleanup()


def add():
    host = target_host
    group = groups.split(",")
    ## find services that this host belogns to
    print "<<<==== 1# Adding Host ===>>>"
    if not nc.get_host(target_host):
        new_host = pynag.Model.Host()
        new_host.set_filename('/etc/nagios/conf.d/hadoop-hosts.cfg')
        new_host.host_name = host
        new_host.address = host
        new_host.alias =  host
        new_host.use = "linux-server"
        new_host.check_command = "check_ping!100.0,20%!500.0,60%"
        new_host.check_interval = "0.25"
        new_host.retry_interval = "0.25"
        new_host.max_check_attempts    =    '4'
        new_host.notifications_enabled  =   '1'
        new_host.first_notification_delay = '0   # Send notification soon after change in the hard state'
        new_host.notification_interval   =  '0    # Send the notification once'
        new_host.notification_options   =   'd,u,r'
        new_host.set_macro('$_HOSTsubject$', env)
        new_host.save()
        sys.stdout.write("%s Successfully Added\n" % ( target_host ))
    else:
        sys.stderr.write("%s already exists\n" % ( target_host ))


    print "<<<==== 2# Adding Host into group ===>>>"
    for hostgroup in group:
        hostgroup_obj = nc.get_hostgroup(hostgroup)
        if not hostgroup_obj:
            sys.stderr.write("Hostgroup not found: %s\n" % hostgroup)
            continue
        member_list = sorted(set(nc._get_list(hostgroup_obj, 'members')))
        if host in member_list:
            print "Host %s already in %s Group" % ( host, hostgroup)
        else:
            member_list.append(host)
            nc['all_hostgroup'].remove(hostgroup_obj)
            hostgroup_obj['meta']['needs_commit'] = True
            member_string = ",".join(member_list)
            hostgroup_obj['members'] = ",".join(member_list)
            nc['all_hostgroup'].append(hostgroup_obj)
            nc.commit()
            print "Host %s Successfully Added in %s Group" % ( host, hostgroup)


def delete():

    #1 Deleting Service for target host
    print "<<<==== 1# Deleting Host service ===>>>"
    try:
        for service_description in nc.get_host(target_host)['meta']['service_list']:
            print "Deleting Service"
            service = nc.get_service(target_host, service_description)
            # ## Check to see if this is the only host in this service
            host_list = []
            if service != None:
                if service.has_key('host_name'):
                   for host in nc._get_list(service, 'host_name'):
                       if host[0] != "!":
                           host_list.append(host)
                else:
                    continue


            ## Ignore if this host isn't listed
            if len(host_list) == 0:
                continue

            if len(host_list) > 1:
                print "Removing %s from %s" % (target_host, service['service_description'])
                new_item = nc.get_service(service['service_description'],target_host)
                host_list.remove(target_host)
                host_string = ",".join(host_list)
                print "New Value: %s" % host_string
                nc.edit_service(target_host,service['service_description'],'host_name', host_string)
            elif (len(host_list) == 1) and not service.has_key('hostgroup_name'):
                print "Deleting %s" % service['service_description']
                nc.delete_service(service['service_description'],target_host)
            elif (len(host_list) == 1) and (host_list[0] is target_host):
                print "Deleting %s" % service['service_description']
                nc.delete_service(service['service_description'],target_host)
            else:
                print "Unknown Action"
                sys.exit(1)

            nc.commit()
    except Exception:
        print "No service found for host %s" % target_host
        pass

    #2 Deleting targest host from hostsgroup
    group_list = [i.hostgroup_name for i in pynag.Model.Hostgroup.objects.all]
    ## Find the hostgroup from our global dictionaries
    print "<<<==== 2# Deleting Host from group ===>>>"
    for target_group in group_list:
        group_obj = nc.get_hostgroup(target_group)
        if not target_group:
            continue
        if not group_obj:
            sys.stderr.write("%s does not exist\n" % target_group)
            continue

        ## Get a list of the host_name's in this group
        try:
            existing_list = sorted(set(group_obj['members'].split(",")))
            if target_host not in existing_list:
                #sys.stderr.write("%s is not in the group: %s\n" % (target_host, target_group ))
                continue
            else:
                existing_list.remove(target_host)

            print "Removing %s from %s" % (target_host, target_group)

            ## Alphabetize the list, for easier readability (and to make it pretty)
            existing_list = sorted(set(existing_list))

            ## Remove old group
            nc['all_hostgroup'].remove(group_obj)

            ## Save the new member list
            group_obj['members'] = ",".join(existing_list)

            ## Mark the commit flag for the group
            group_obj['meta']['needs_commit'] = True

            ## Add the group back in with new members
            nc['all_hostgroup'].append(group_obj)

            ## Commit the changes to file
            nc.commit()
        except Exception:
            print "Next Group %s" % target_group
            pass



    #3 Finally delete host
    print "<<<==== 3# Deleting Host ===>>>"
    result = nc.delete_object('host', target_host)
    if result:
        print "Deleted host"
    else:
       print "%s does not exists" % target_host
    nc.commit()
    nc.cleanup()


if __name__ == '__main__':
    args = docopt.docopt(usage,version='version 0.1 by Rahul Patil<http://linuxian.com>')
    print args
    if args['--add']:
       target_host,env,groups = args['<fqdn>'],args['<environment>'],args['<groups>']
       add()
    elif args['--del']:
       target_host = args['<fqdn>']
       delete()
    else:
      sys.exit(1)
