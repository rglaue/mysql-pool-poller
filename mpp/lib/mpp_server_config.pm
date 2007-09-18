package mpp_server_config;

sub config {
    return	{
	pooled	=>	{
		'192.168.2.1'	=>	{
			'3306'	=>	{
					pool	=>	'pro_mysql.e.org_pool',
					loc	=>	'site-A',
					ploc	=>	'site-A',
					port	=>	'3306',
					name	=>	'realservername-1.db.site-A.e.org',
					vhost	=>	'pro_mysql.site-A.e.org',
					type	=>	'real'
					}
					},
		'192.168.13.1'	=>	{
			'3306'	=>	{
					pool	=>	'pro_mysql.e.org_pool',
					loc	=>	'site-A',
					ploc	=>	'site-B',
					port	=>	'3306',
					name	=>	'pro_mysql.site-A.e.org',
					vhost	=>	'pro_mysql.e.org',
					type	=>	'virtual'
					}
					},
		'192.168.12.1'	=>	{
			'3306'	=>	{
					pool	=>	'pro_mysql.e.org_pool',
					loc	=>	'site-B',
					ploc	=>	'site-B',
					port	=>	'3306',
					name	=>	'realservername-1.db.site-B.e.org',
					vhost	=>	'pro_mysql.site-B.e.org',
					type	=>	'real'
					}
					},
		'192.168.3.1'	=>	{
			'3306'	=>	{
					pool	=>	'pro_mysql.e.org_pool',
					loc	=>	'site-B',
					ploc	=>	'site-A',
					port	=>	'3306',
					name	=>	'pro_mysql.site-B.e.org',
					vhost	=>	'pro_mysql.e.org',
					type	=>	'virtual'
					}
					},

		'192.168.2.2'	=>	{
			'3306'	=>	{
					pool	=>	'dem_mysql.e.org_pool',
					loc	=>	'site-A',
					ploc	=>	'site-A',
					port	=>	'3306',
					name	=>	'realservername-2.db.site-A.e.org',
					vhost	=>	'dem_mysql.site-A.e.org',
					type	=>	'real'
					}
					},
		'192.168.13.2'	=>	{
			'3306'	=>	{
					pool	=>	'dem_mysql.e.org_pool',
					loc	=>	'site-A',
					ploc	=>	'site-B',
					port	=>	'3306',
					name	=>	'dem_mysql.site-A.e.org',
					vhost	=>	'dem_mysql.e.org',
					type	=>	'virtual'
					}
					},
		'192.168.12.2'	=>	{
			'3306'	=>	{
					pool	=>	'dem_mysql.e.org_pool',
					loc	=>	'site-B',
					ploc	=>	'site-B',
					port	=>	'3306',
					name	=>	'realservername-2.db.site-B.e.org',
					vhost	=>	'dem_mysql.site-B.e.org',
					type	=>	'real'
					}
					},
		'192.168.3.2'	=>	{
			'3306'	=>	{
					pool	=>	'dem_mysql.e.org_pool',
					loc	=>	'site-B',
					ploc	=>	'site-A',
					port	=>	'3306',
					name	=>	'dem_mysql.site-B.e.org',
					vhost	=>	'dem_mysql.e.org',
					type	=>	'virtual'
					}
					},

			},
	global	=>	{
		'pro_mysql.e.org'
				=>	{
					pool	=>	'pro_mysql.e.org_pool',
					ploc	=>	['site-A', 'site-B'],
					port	=>	'3306',
					},
		'dem_mysql.e.org'
				=>	{
					pool	=>	'dem_mysql.e.org_pool',
					ploc	=>	['site-A','site-B'],
					port	=>	'3306',
					}
			}
		};
}
1;
