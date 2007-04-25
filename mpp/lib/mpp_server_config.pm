package mpp_server_config;

sub config {
    return	{
	pooled	=>	{
		'172.18.5.22'	=>	{
			'3306'	=>	{
					pool	=>	'pro.dm1_3dns_1',
					loc	=>	'ma',
					ploc	=>	'ma',
					port	=>	'3306',
					name	=>	'gallium-v1.db.ma.cait.org',
					vhost	=>	'pro.dm1.mysql.ma.cait.org',
					type	=>	'real'
					}
					},
		'172.18.10.32'	=>	{
			'3306'	=>	{
					pool	=>	'pro.dm1_3dns_1',
					loc	=>	'ma',
					ploc	=>	'cu',
					port	=>	'3306',
					name	=>	'pro.dm1.mysql.ma.cait.org',
					vhost	=>	'pro.dm1.mysql.cait.org',
					type	=>	'virtual'
					}
					},
		'172.18.37.22'	=>	{
			'3306'	=>	{
					pool	=>	'pro.dm1_3dns_1',
					loc	=>	'cu',
					ploc	=>	'cu',
					port	=>	'3306',
					name	=>	'duvel-v1.db.cu.cait.org',
					vhost	=>	'pro.dm1.mysql.cu.cait.org',
					type	=>	'real'
					}
					},
		'172.18.42.32'	=>	{
			'3306'	=>	{
					pool	=>	'pro.dm1_3dns_1',
					loc	=>	'cu',
					ploc	=>	'ma',
					port	=>	'3306',
					name	=>	'pro.dm1.mysql.cu.cait.org',
					vhost	=>	'pro.dm1.mysql.cait.org',
					type	=>	'virtual'
					}
					},


		'172.18.5.23'	=>	{
			'3306'	=>	{
					pool	=>	'dem.dm1_3dns_1',
					loc	=>	'ma',
					ploc	=>	'ma',
					port	=>	'3306',
					name	=>	'gallium-v2.db.ma.cait.org',
					vhost	=>	'dem.dm1.mysql.ma.cait.org',
					type	=>	'real'
					}
					},
		'172.18.10.31'	=>	{
			'3306'	=>	{
					pool	=>	'dem.dm1_3dns_1',
					loc	=>	'ma',
					ploc	=>	'cu',
					port	=>	'3306',
					name	=>	'dem.dm1.mysql.ma.cait.org',
					vhost	=>	'dem.dm1.mysql.cait.org',
					type	=>	'virtual'
					}
					},
		'172.18.37.23'	=>	{
			'3306'	=>	{
					pool	=>	'dem.dm1_3dns_1',
					loc	=>	'cu',
					ploc	=>	'cu',
					port	=>	'3306',
					name	=>	'duvel-v2.db.cu.cait.org',
					vhost	=>	'dem.dm1.mysql.cu.cait.org',
					type	=>	'real'
					}
					},
		'172.18.42.31'	=>	{
			'3306'	=>	{
					pool	=>	'dem.dm1_3dns_1',
					loc	=>	'cu',
					ploc	=>	'ma',
					port	=>	'3306',
					name	=>	'dem.dm1.mysql.cu.cait.org',
					vhost	=>	'dem.dm1.mysql.cait.org',
					type	=>	'virtual'
					}
					},


		'172.18.5.24'	=>	{
			'3306'	=>	{
					pool	=>	'dev.dm1_3dns_1',
					loc	=>	'ma',
					ploc	=>	'ma',
					port	=>	'3306',
					name	=>	'gallium-v3.db.ma.cait.org',
					vhost	=>	'dev.dm1.mysql.ma.cait.org',
					type	=>	'real'
					}
					},
		'172.18.10.30'	=>	{
			'3306'	=>	{
					pool	=>	'dev.dm1_3dns_1',
					loc	=>	'ma',
					ploc	=>	'cu',
					port	=>	'3306',
					name	=>	'dev.dm1.mysql.ma.cait.org',
					vhost	=>	'dev.dm1.mysql.cait.org',
					type	=>	'virtual'
					}
					},
		'172.18.37.24'	=>	{
			'3306'	=>	{
					pool	=>	'dev.dm1_3dns_1',
					loc	=>	'cu',
					ploc	=>	'cu',
					port	=>	'3306',
					name	=>	'duvel-v3.db.cu.cait.org',
					vhost	=>	'dev.dm1.mysql.cu.cait.org',
					type	=>	'real'
					}
					},
		'172.18.42.30'	=>	{
			'3306'	=>	{
					pool	=>	'dev.dm1_3dns_1',
					loc	=>	'cu',
					ploc	=>	'ma',
					port	=>	'3306',
					name	=>	'dev.dm1.mysql.cu.cait.org',
					vhost	=>	'dev.dm1.mysql.cait.org',
					type	=>	'virtual'
					}
					},


		'172.18.5.25'	=>	{
			'3306'	=>	{
					pool	=>	'dh1_3dns_1',
					loc	=>	'ma',
					ploc	=>	'ma',
					port	=>	'3306',
					name	=>	'gallium-v4.db.ma.cait.org',
					vhost	=>	'dh1.mysql.ma.cait.org',
					type	=>	'real'
					}
					},
		'172.18.10.33'	=>	{
			'3306'	=>	{
					pool	=>	'dh1_3dns_1',
					loc	=>	'ma',
					ploc	=>	'cu',
					port	=>	'3306',
					name	=>	'dh1.mysql.ma.cait.org',
					vhost	=>	'dh1.mysql.cait.org',
					type	=>	'virtual'
					}
					},
		'172.18.37.25'	=>	{
			'3306'	=>	{
					pool	=>	'dh1_3dns_1',
					loc	=>	'cu',
					ploc	=>	'cu',
					port	=>	'3306',
					name	=>	'duvel-v4.db.cu.cait.org',
					vhost	=>	'dh1.mysql.cu.cait.org',
					type	=>	'real'
					}
					},
		'172.18.42.33'	=>	{
			'3306'	=>	{
					pool	=>	'dh1_3dns_1',
					loc	=>	'cu',
					ploc	=>	'ma',
					port	=>	'3306',
					name	=>	'dh1.mysql.cu.cait.org',
					vhost	=>	'dh1.mysql.cait.org',
					type	=>	'virtual'
					}
					},


		'172.18.5.26'	=>	{
			'3306'	=>	{
					pool	=>	'pro.im1_3dns_1',
					loc	=>	'ma',
					ploc	=>	'ma',
					port	=>	'3306',
					name	=>	'zirconium-v1.db.ma.cait.org',
					vhost	=>	'pro.im1.mysql.ma.cait.org',
					type	=>	'real'
					}
					},
		'172.18.10.36'	=>	{
			'3306'	=>	{
					pool	=>	'pro.im1_3dns_1',
					loc	=>	'ma',
					ploc	=>	'cu',
					port	=>	'3306',
					name	=>	'pro.im1.mysql.ma.cait.org',
					vhost	=>	'pro.im1.mysql.cait.org',
					type	=>	'virtual'
					}
					},
		'172.18.37.26'	=>	{
			'3306'	=>	{
					pool	=>	'pro.im1_3dns_1',
					loc	=>	'cu',
					ploc	=>	'cu',
					port	=>	'3306',
					name	=>	'stone-v1.db.cu.cait.org',
					vhost	=>	'pro.im1.mysql.cu.cait.org',
					type	=>	'real'
					}
					},
		'172.18.42.36'	=>	{
			'3306'	=>	{
					pool	=>	'pro.im1_3dns_1',
					loc	=>	'cu',
					ploc	=>	'ma',
					port	=>	'3306',
					name	=>	'pro.im1.mysql.cu.cait.org',
					vhost	=>	'pro.im1.mysql.cait.org',
					type	=>	'virtual'
					}
					},

		'172.18.5.27'	=>	{
			'3306'	=>	{
					pool	=>	'pro.im2_3dns_1',
					loc	=>	'ma',
					ploc	=>	'ma',
					port	=>	'3306',
					name	=>	'zirconium-v2.db.ma.cait.org',
					vhost	=>	'pro.im2.mysql.ma.cait.org',
					type	=>	'real'
					},
			'3307'	=>	{
					pool	=>	'pro.im3_3dns_1',
					loc	=>	'ma',
					ploc	=>	'ma',
					port	=>	'3307',
					name	=>	'zirconium-v2.db.ma.cait.org',
					vhost	=>	'pro.im3.mysql.ma.cait.org',
					type	=>	'real'
					}
					},
		'172.18.10.38'	=>	{
			'3306'	=>	{
					pool	=>	'pro.im2_3dns_1',
					loc	=>	'ma',
					ploc	=>	'cu',
					port	=>	'3306',
					name	=>	'pro.im2.mysql.ma.cait.org',
					vhost	=>	'pro.im2.mysql.cait.org',
					type	=>	'virtual'
					}
					},
		'172.18.37.27'	=>	{
			'3306'	=>	{
					pool	=>	'pro.im2_3dns_1',
					loc	=>	'cu',
					ploc	=>	'cu',
					port	=>	'3306',
					name	=>	'stone-v2.db.cu.cait.org',
					vhost	=>	'pro.im2.mysql.cu.cait.org',
					type	=>	'real'
					},
			'3307'	=>	{
					pool	=>	'pro.im3_3dns_1',
					loc	=>	'cu',
					ploc	=>	'cu',
					port	=>	'3307',
					name	=>	'stone-v2.db.cu.cait.org',
					vhost	=>	'pro.im3.mysql.cu.cait.org',
					type	=>	'real'
					}
					},
		'172.18.42.38'	=>	{
			'3306'	=>	{
					pool	=>	'pro.im2_3dns_1',
					loc	=>	'cu',
					ploc	=>	'ma',
					port	=>	'3306',
					name	=>	'pro.im2.mysql.cu.cait.org',
					vhost	=>	'pro.im2.mysql.cait.org',
					type	=>	'virtual'
					}
					},

		'172.18.10.39'	=>	{
			'3306'	=>	{
					pool	=>	'pro.im3_3dns_1',
					loc	=>	'ma',
					ploc	=>	'cu',
					port	=>	'3306',
					name	=>	'pro.im3.mysql.ma.cait.org',
					vhost	=>	'pro.im3.mysql.cait.org',
					type	=>	'virtual'
					}
					},
		'172.18.42.39'	=>	{
			'3306'	=>	{
					pool	=>	'pro.im3_3dns_1',
					loc	=>	'cu',
					ploc	=>	'ma',
					port	=>	'3306',
					name	=>	'pro.im3.mysql.cu.cait.org',
					vhost	=>	'pro.im3.mysql.cait.org',
					type	=>	'virtual'
					}
					},

		'172.18.5.28'	=>	{
			'3306'	=>	{
					pool	=>	'dem.im1_3dns_1',
					loc	=>	'ma',
					ploc	=>	'ma',
					port	=>	'3306',
					name	=>	'zirconium-v3.db.ma.cait.org',
					vhost	=>	'dem.im1.mysql.ma.cait.org',
					type	=>	'real'
					},
			'3307'	=>	{
					pool	=>	'dev.im1_3dns_1',
					loc	=>	'ma',
					ploc	=>	'ma',
					port	=>	'3306',
					name	=>	'zirconium-v3.db.ma.cait.org',
					vhost	=>	'dev.im1.mysql.ma.cait.org',
					type	=>	'real'
					}
					},
		'172.18.10.35'	=>	{
			'3306'	=>	{
					pool	=>	'dem.im1_3dns_1',
					loc	=>	'ma',
					ploc	=>	'cu',
					port	=>	'3306',
					name	=>	'dem.im1.mysql.ma.cait.org',
					vhost	=>	'dem.im1.mysql.cait.org',
					type	=>	'virtual'
					}
					},
		'172.18.10.34'	=>	{
			'3306'	=>	{
					pool	=>	'dev.im1_3dns_1',
					loc	=>	'ma',
					ploc	=>	'cu',
					port	=>	'3306',
					name	=>	'dev.im1.mysql.ma.cait.org',
					vhost	=>	'dev.im1.mysql.cait.org',
					type	=>	'virtual'
					}
					},
		'172.18.37.28'	=>	{
			'3306'	=>	{
					pool	=>	'dem.im1_3dns_1',
					loc	=>	'cu',
					ploc	=>	'cu',
					port	=>	'3306',
					name	=>	'stone-v3.db.cu.cait.org',
					vhost	=>	'dem.im1.mysql.cu.cait.org',
					type	=>	'real'
					},
			'3307'	=>	{
					pool	=>	'dev.im1_3dns_1',
					loc	=>	'cu',
					ploc	=>	'cu',
					port	=>	'3306',
					name	=>	'stone-v3.db.cu.cait.org',
					vhost	=>	'dev.im1.mysql.cu.cait.org',
					type	=>	'real'
					}
					},
		'172.18.42.35'	=>	{
			'3306'	=>	{
					pool	=>	'dem.im1_3dns_1',
					loc	=>	'cu',
					ploc	=>	'ma',
					port	=>	'3306',
					name	=>	'dem.im1.mysql.cu.cait.org',
					vhost	=>	'dem.im1.mysql.cait.org',
					type	=>	'virtual'
					}
					},
		'172.18.42.34'	=>	{
			'3306'	=>	{
					pool	=>	'dev.im1_3dns_1',
					loc	=>	'cu',
					ploc	=>	'ma',
					port	=>	'3306',
					name	=>	'dev.im1.mysql.cu.cait.org',
					vhost	=>	'dev.im1.mysql.cait.org',
					type	=>	'virtual'
					}
					},

		'172.18.5.29'	=>	{
			'3306'	=>	{
					pool	=>	'ih1_3dns_1',
					loc	=>	'ma',
					ploc	=>	'ma',
					port	=>	'3306',
					name	=>	'zirconium-v4.db.ma.cait.org',
					vhost	=>	'ih1.mysql.ma.cait.org',
					type	=>	'real'
					}
					},
		'172.18.10.37'	=>	{
			'3306'	=>	{
					pool	=>	'ih1_3dns_1',
					loc	=>	'ma',
					ploc	=>	'cu',
					port	=>	'3306',
					name	=>	'ih1.mysql.ma.cait.org',
					vhost	=>	'ih1.mysql.cait.org',
					type	=>	'virtual'
					}
					},
		'172.18.37.29'	=>	{
			'3306'	=>	{
					pool	=>	'ih1_3dns_1',
					loc	=>	'cu',
					ploc	=>	'cu',
					port	=>	'3306',
					name	=>	'stone-v4.db.cu.cait.org',
					vhost	=>	'ih1.mysql.cu.cait.org',
					type	=>	'real'
					}
					},
		'172.18.42.37'	=>	{
			'3306'	=>	{
					pool	=>	'ih1_3dns_1',
					loc	=>	'cu',
					ploc	=>	'ma',
					port	=>	'3306',
					name	=>	'ih1.mysql.cu.cait.org',
					vhost	=>	'ih1.mysql.cait.org',
					type	=>	'virtual'
					}
					},
			},
	global	=>	{
		'pro.dm1.mysql.cait.org'
				=>	{
					pool	=>	'pro.dm1_3dns_1',
					ploc	=>	['ma', 'cu'],
					port	=>	'3306',
					},
		'dem.dm1.mysql.cait.org'
				=>	{
					pool	=>	'dem.dm1_3dns_1',
					ploc	=>	['ma','cu'],
					port	=>	'3306',
					},
		'dev.dm1.mysql.cait.org'
				=>	{
					pool	=>	'dev.dm1_3dns_1',
					ploc	=>	['ma','cu'],
					port	=>	'3306',
					},
		'dh1.mysql.cait.org'
				=>	{
					pool	=>	'dh1_3dns_1',
					ploc	=>	['ma','cu'],
					port	=>	'3306',
					},
		'pro.im1.mysql.cait.org'
				=>	{
					pool	=>	'pro.im1_3dns_1',
					ploc	=>	['ma', 'cu'],
					port	=>	'3306',
					},
		'pro.im2.mysql.cait.org'
				=>	{
					pool	=>	'pro.im2_3dns_1',
					ploc	=>	['ma', 'cu'],
					port	=>	'3306',
					},
		'pro.im3.mysql.cait.org'
				=>	{
					pool	=>	'pro.im3_3dns_1',
					ploc	=>	['ma', 'cu'],
					port	=>	'3306',
					},
		'dem.im1.mysql.cait.org'
				=>	{
					pool	=>	'dem.im1_3dns_1',
					ploc	=>	['ma','cu'],
					port	=>	'3306',
					},
		'dev.im1.mysql.cait.org'
				=>	{
					pool	=>	'dev.im1_3dns_1',
					ploc	=>	['ma','cu'],
					port	=>	'3306',
					},
		'ih1.mysql.cait.org'
				=>	{
					pool	=>	'ih1_3dns_1',
					ploc	=>	['ma','cu'],
					port	=>	'3306',
					}
			}
		};
}
1;
