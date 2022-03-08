(this is an archived site) 

MPP
---

#### [CodePin.cait.org](http://codepin.cait.org)

* * *

  

**ABOUT**

#### MPP

MPP is a MySQL State Manager for MySQL server failover negotiation and management. It is intended to be used as a 2nd party management application used in combination with any load balancing management software. It was initially designed to be used in conjunction with Linux Virtual Server, and later F5 Networks BigIP, but can work with any load balancer that can utilize external check scripts or accomplish an HTTP REST call. MPP now integrates with MySQL Proxy using an injection mechanism.  
  
This software allows the configuration of MySQL servers into a pool. The configured pool is managed based on a logic that is assigned to it. MPP currently supports generic fail-over logic, and has intentions to eventually support generic cluster logic.  
  
MPP began it's origins in the 2nd half of 2004, and was released into internal production as proof-of-concept in 2005. Two and a half years later after testing in a variety of production environments with integration in several 2nd party controllers, and sights set on MySQL Proxy integration, it is released.  
  
MPP is written in PERL, released as Open Source Apache 2 license which is compatible with GPL 3.

#### MPP Web Service

The MPP Web Service and Web Client is currently released as gamma. It provides a Web 2.0 interface to MPP cache files. The polling daemon currently keeps monitoring data current in the cache, and the Web Service makes the results, currently as read-only, available to any Web 2.0 able client via REST.  
  
A Web 2.0 Client dashboard is bundled with the Web Service. The Web Client uses XSLT to transform the MPP data into an initial dashboard, and JSON to keep monitored objects in the dashboard updated from the Web Service.  
  
Both Web Service and Client use XML::TreePP and [XML::TreePP::XMLPath](/project/perlmod/XML-TreePP-XMLPath), the later module which makes any PERL hash/array ref structure accessible via an XPath-like accessor methodology.  
  
The Web Service will be merged into the MPP core at a later date when it matures.

  

**INTEGRATION**

MPP was written as a 2nd party plugin to controllers. These controllers are what enact the physical change of state of MySQL nodes.

*   MPP has been tested under the following controllers:
    
    *   [Linux Virtual Server](http://www.linuxvirtualserver.org/)
    *   [Red Hat Clustering Suite, Piranha](http://www.redhat.com/software/rha/cluster/)
    *   [F5 Network SmartDNS](http://www.f5.com/)
    *   [F5 Network Big IP](http://www.f5.com/)
    *   [MySQL Proxy](http://forge.mysql.com/wiki/MySQL_Proxy) (work completed r1.0.1, initial testing completed r1.0.3)
    

  

**REQUIREMENTS**

The PERL requirements for using MPP is as follows:

  MODULE	MIN VERSION	AVAILABLE
  -----------	-----------	--------------
  CGIbasic	0.010		MPP Bundled
  Config\_info	1.00803		MPP Bundled
  LogBasic	0.00.003	MPP Bundled
  Storable	PERL >= 5.8	PERL Bundled
  Net::HTTP	PERL >= 5.8	PERL Bundled
  Net::Ping	PERL >= 5.8	PERL Bundled
  IO::FILE	PERL >= 5.8	PERL Bundled
  DBD::MySQL	2.9006		CPAN
  DBI		1.46		CPAN

The PERL requirements for using the MPP Web Service is as follows:

*   Web Service
    *   Data::Dump
    *   XML::TreePP
    *   XML::TreePP::XMLPath
*   Web Client
    *   Data::Dump
    *   XML::TreePP
    *   XML::TreePP::XMLPath
    *   XML::XSLT
    *   XML::Tidy
    *   CGI
    *   JSON::PP
        

  

**AVAILABILITY**

This software was recently imported from our internal engineering lab, and has been merged with modification recomendations from our real world implementation. The resulting code available here has been tested and considered ready for release.

#### Documentation

Read an overview in articles on MPP and State Management on the MySQL Developer Zone:

*   [MySQL Failover Strategy using State Management, introducing MPP - Part 1](/project/mpp/docs/article1-part1/)
    
    _Having a strategy for failover has become almost standard in the business world. Whether it is a total site failover from a NOC in one city to another, or just a simple redundant server. Over the years many technology solutions have been created for or adopted to MySQL to provide this type of strategy._
    
      
    
*   [MySQL Failover Strategy using State Management, introducing MPP - Part 2](/project/mpp/docs/article1-part2/)
    
    _In Part 1 we have seen how the concept of state management works. Now it's time to apply that concept to a load-balancer. In this Part 2 we will look at a strategy for using Linux Virtual Server with MPP for failover, and also take a closer look at the mechanics of MPP itself._
    
      
    
*   [MySQL Failover Strategy using State Management, introducing MPP - Part 3](/project/mpp/docs/article1-part3/)
    
    _In part 2 we discussed the internals of MPP and how MPP can be used with LVS to create a failover strategy. In this part 3 we will discuss how to configure and operate MPP, and additionally use MPP with MySQL Proxy to create a failover strategy._
    
      
    

View the MPP [INSTALL](https://dev-codepin.cait.org/scm/viewvc/mpp/trunk/mpp/INSTALL), [LICENSE](https://dev-codepin.cait.org/scm/viewvc/mpp/trunk/mpp/LICENSE), [NOTICE](https://dev-codepin.cait.org/scm/viewvc/mpp/trunk/mpp/NOTICE), [README](https://dev-codepin.cait.org/scm/viewvc/mpp/trunk/mpp/README), [CHANGES](https://dev-codepin.cait.org/scm/viewvc/mpp/trunk/mpp/CHANGES), [TODO](https://dev-codepin.cait.org/scm/viewvc/mpp/trunk/mpp/TODO) online.  
View the MPP [Subversion repository](https://dev-codepin.cait.org/scm/viewvc/mpp) online.  
View the MPP Web Service [README](https://dev-codepin.cait.org/scm/viewvc/mpp/branches/mpp-ws/README), [CHANGES](https://dev-codepin.cait.org/scm/viewvc/mpp/branches/mpp-ws/CHANGES) online.

#### Get the code

You can download the source code from Subversion.

*   Subversion trunk: [https://dev-codepin.cait.org/svn/mpp/trunk/mpp](https://dev-codepin.cait.org/svn/mpp/trunk/mpp)
*   Subversion tags (revisions): [https://dev-codepin.cait.org/svn/mpp/tags/mpp](https://dev-codepin.cait.org/svn/mpp/tags/mpp)
*   **Latest Revisions:**
    
    date
    
    revision
    
    tarball
    
    summarized description
    
    2007.12.10
    
    1.0.3
    
    [mpp-1.0.3.tgz](archive/mpp-1.0.3.tgz)
    
    `mysql-polld` daemon-like script is created for the replacement of the cron option for polling nodes. Initial testing for integration with MySQL Proxy 0.6.0 has been completed. Various fixes and updates.
    
    2007.11.16
    
    1.0.2
    
    [mpp-1.0.2.tgz](archive/mpp-1.0.2.tgz)
    
    The `mpp.lua` file has been updated to address an issue I refer to as "all\_node\_down", where all Proxy backend servers are down and MPP cannot connect to load its evaluations into Proxy. This version also address the issue where you could not supply a blank password to `mpp-proxyadmin.pl`. This version also contains a work around for MySQL [Bug #32464](http://bugs.mysql.com/32464) for DBD::mysql.
    
    2007.11.13
    
    1.0.1
    
    [mpp-1.0.1.tgz](archive/mpp-1.0.1.tgz)
    
    Integration with MySQL Proxy Tested. Added a `mysqlproxy` host module into the API set, `mpp.lua` Lua script for MySQL Proxy, and created an admin application `mpp-proxyadmin.pl` to manage MPP evaluations from MPP cache into Proxy internals.
    
    2007.11.11
    
    1.0.0
    
    [mpp-1.0.0.tgz](archive/mpp-1.0.0.tgz)
    
    First release. Integration with Linux Virtual Server and F5 Networks BigIP tested.
    

The code for MPP Web Service is available for download:

*   Web Service revisions: [https://dev-codepin.cait.org/svn/mpp/tags/mpp-ws](https://dev-codepin.cait.org/svn/mpp/tags/mpp-ws)
*   **Web Service Latest Revisions:**
    
    date
    
    revision
    
    tarball
    
    summarized description
    
    2009.06.30
    
    0.0.1-gamma
    
    [mpp-ws-0.0.1-gamma.tgz](archive/mpp-ws-0.0.1-gamma.tgz)
    
    First release. A read-only dashboard to MPP Monitoring data.
    

  

**FUTURE**

There is a plan in progress that MPP will be combined into MySQL Proxy. The plan is multi-phased:

1.  MPP revision 1.0.1 gave us MySQLProxy+MPP combination by handshake - getting them to talk to each other.
2.  MPP Revision 1.0.3 gave us a daemon to perform the polling, rather than relying on cron for implementation  
    _Depending on how MySQL Proxy evolves, one of the two will happen:_
    1.  A newer web 2.0 enabled polling manager daemon process
    2.  Polling managed by Proxy, and manageable through a web 2.0 interface
3.  We want these load balancing methods in MySQL Proxy using Lua, and relying on MPP for the logic:
    *   round robin (this is the default, and currently the only implementation)
    *   read-only versus read-write, SQL query load balancing (this is the next desired implementation)
    *   weighted connections
    *   least connections
    *   weighted least connections
4.  _Depending on the future development of MySQL Proxy, the following may happen:_
    1.  Parts of MPP converted in Lua Snipits using PERL [Inline::Lua](http://search.cpan.org/~vparseval/Inline-Lua-0.03/lib/Inline/Lua.pm); Lua Snipts integrated into MySQL Proxy.
    2.  Merging of MPP into MySQL Proxy without external dependencies, with the following attributions:
        *   MPP-as-Lua still packageable into a MPP PERL-library using Inline:Lua for 2nd party integration into other controllers.
        *   MPP Clients can/will be written for managing MPP logic in a running MySQL Proxy implementation of MPP.  
                 (This allows the administrator to say, "Uh.. change your mind to make this decision instead." Ex: "I don't care if the STANDBY is in \[replication\] FAILure, promote it to ACTIVE and fail-over to it anyway.")

**Purpose:** MPP has the ability right now to supervise master fail-over. The physical execution of a master fail-over is still reliant upon a controller like MySQL Proxy.  
MPP was written to act as a plugin, to add intelligence to 2nd party controllers. MPP negotiates MySQL node States of ACTIVE, STANDBY, FAIL and Statuses of OK, INFO, WARN, CRITICAL, FAIL in a transitional flow.

**Project NEWS**

[View RSS feed](http://itde.vccs.edu/rss2js/feed2js.php?src=http%3A%2F%2Frglaue-tech.blogspot.com%2Ffeeds%2Fposts%2Fdefault%2F-%2FMPP&chan=n&num=5&desc=1&date=y&targ=n&html=y)

  

* * *

[CodePin.cait.org](http://codepin.cait.org), © 2006 - 2009 [Center for the Application of Information Technologies](http://www.cait.org), [Western Illinois University](http://www.wiu.edu)
