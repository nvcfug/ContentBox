/**
* Installs ContentBox
*/
component accessors="true"{

	// DI
	property name="authorService" 		inject="authorService@cb";
	property name="settingService" 		inject="settingService@cb";
	property name="categoryService" 	inject="categoryService@cb";
	property name="pageService"			inject="pageService@cb";
	property name="entryService"		inject="entryService@cb";
	property name="commentService"		inject="commentService@cb";
	property name="customHTMLService"	inject="customHTMLService@cb";
	property name="roleService" 		inject="roleService@cb";
	property name="permissionService" 	inject="permissionService@cb";
	property name="securityRuleService" inject="securityRuleService@cb";
	property name="appPath" 			inject="coldbox:setting:applicationPath";
	property name="securityInterceptor" inject="securityInterceptor@cb";
	property name="coldbox"				inject="coldbox";

	/**
	* Constructor
	*/
	InstallerService function init(){
		permissions = {};
		return this;
	}

	/**
	* Execute the installer
	*/
	function execute(required setup) transactional{

		// process rerwite
		if( setup.getFullRewrite() ){
			processRewrite( setup );
		}

		// create roles
		var adminRole = createRoles( setup );
		// create Author
		var author = createAuthor( setup, adminRole );
		// create All Settings
		createSettings( setup );
		// create all security rules
		createSecurityRules( setup );
		// Do we create sample data?
		if( setup.getpopulateData() ){
			createSampleData( setup, author );
		}
		// Remove ORM update from Application.cfc
		processORMUpdate( setup );
		// Process reinit and debug password security
		processColdBoxPasswords( setup );
		// ContentBox is now online, mark it:
		settingService.activateCB();
		// Reload Security Rules
		securityInterceptor.loadRules();
	}

	function createSecurityRules(required setup){
		securityRuleService.resetRules();
	}

	function processORMUpdate(required setup){
		var appCFCPath = appPath & "Application.cfc";
		var c = fileRead(appCFCPath);
		c = replacenocase(c, '"update"','"none"');
		fileWrite(appCFCPath, c);
	}

	function processColdBoxPasswords(required setup){
		var configPath = appPath & "config/Coldbox.cfc";
		var c = fileRead(configPath);
		var newPass = hash( now() & setup.getUniqueHash() ,"MD5");
		c = replacenocase(c, "@fwPassword@", newPass,"all");
		fileWrite(configPath, c);
		coldbox.setSetting("debugPassword", newpass);
		coldbox.setSetting("reinitPassword", newpass);
	}

	function processRewrite(required setup){
		var routesPath = appPath & "config/Routes.cfm";
		var c = fileRead(routesPath);
		c = replacenocase(c, "index.cfm","","all");
		fileWrite(routesPath, c);
	}

	/**
	* Create permissions
	*/
	function createPermissions(required setup ){
		var perms = {
			"SYSTEM_TAB" = "Access to the ContentBox System tools",
			"SYSTEM_SAVE_CONFIGURATION" = "Ability to update global configuration data",
			"SYSTEM_RAW_SETTINGS" = "Access to the ContentBox raw geek settings panel",
			"TOOLS_IMPORT" = "Ability to import data into ContentBox",
			"ROLES_ADMIN" = "Ability to manage roles, default is view only",
			"PERMISSIONS_ADMIN" = "Ability to manage permissions, default is view only",
			"AUTHOR_ADMIN" = "Ability to manage authors, default is view only",
			"WIDGET_ADMIN" = "Ability to manage widgets, default is view only",
			"LAYOUT_ADMIN" = "Ability to manage layouts, default is view only",
			"COMMENTS_ADMIN" = "Ability to manage comments, default is view only",
			"CUSTOMHTML_ADMIN" = "Ability to manage custom HTML, default is view only",
			"PAGES_ADMIN" = "Ability to manage content pages, default is view only",
			"PAGES_EDITOR" = "Ability to manage content pages but not publish pages",
			"CATEGORIES_ADMIN" = "Ability to manage categories, default is view only",
			"ENTRIES_ADMIN" = "Ability to manage blog entries, default is view only",
			"ENTRIES_EDITOR" = "Ability to manage blog entries but not publish entries",
			"RELOAD_MODULES" = "Ability to reload modules",
			"SECURITYRULES_ADMIN" = "Ability to manage the system's security rules, default is view only",
			"GLOBALHTML_ADMIN" = "Ability to manage the system's global HTML content used on layouts",
			"EMAIL_TEMPLATE_ADMIN" = "Ability to manage the system's email templates",
			"MEDIAMANAGER_ADMIN" = "Ability to manage the system's media manager",
			"VERSIONS_ROLLBACK" = "Ability to rollback content versions",
			"VERSIONS_DELETE" = "Ability to delete past content versions",
			"SYSTEM_UPDATES" = "Ability to view and apply ContentBox updates",
			"MODULES_ADMIN" = "Ability to manage ContentBox Modules"
		};

		var allperms = [];
		for(var key in perms){
			var props = {permission=key, description=perms[key]};
			permissions[ key ] = permissionService.new(properties=props);
			arrayAppend(allPerms, permissions[ key ] );
		}
		permissionService.saveAll( allPerms );
	}

	/**
	* Create roles and return the admin
	*/
	function createRoles(required setup ){
		// Create Permissions
		createPermissions( setup );

		// Create Editor
		var oRole = roleService.new(properties={role="Editor",description="A ContentBox editor"});
		// Add Editor Permissions
		oRole.addPermission( permissions["COMMENTS_ADMIN"] );
		oRole.addPermission( permissions["CUSTOMHTML_ADMIN"] );
		oRole.addPermission( permissions["PAGES_EDITOR"] );
		oRole.addPermission( permissions["CATEGORIES_ADMIN"] );
		oRole.addPermission( permissions["ENTRIES_EDITOR"] );
		oRole.addPermission( permissions["LAYOUT_ADMIN"] );
		oRole.addPermission( permissions["GLOBALHTML_ADMIN"] );
		oRole.addPermission( permissions["MEDIAMANAGER_ADMIN"] );
		oRole.addPermission( permissions["VERSIONS_ROLLBACK"] );
		roleService.save( oRole );

		// Create Admin
		var oRole = roleService.new(properties={role="Administrator",description="A ContentBox Administrator"});
		// Add All Permissions To Admin
		for(var key in permissions){
			oRole.addPermission( permissions[key] );
		}
		roleService.save( oRole );

		return oRole;
	}

	/**
	* Create author
	*/
	function createAuthor(required setup, required adminRole){
		var oAuthor = authorService.new(properties=setup.getUserData());
		oAuthor.setIsActive( true );
		oAuthor.setRole( adminRole );
		authorService.saveAuthor( oAuthor );

		return oAuthor;
	}

	/**
	* Create settings
	*/
	function createSettings(required setup){

		// Create Settings
		var settings = {
			// User Input Settings
			"cb_site_name" = setup.getSiteName(),
			"cb_site_email" = setup.getSiteEmail(),
			"cb_site_tagline" = setup.getSiteTagLine(),
			"cb_site_description" = setup.getSiteDescription(),
			"cb_site_keywords" = setup.getSiteKeyWords(),
			"cb_site_outgoingEmail" = setup.getSiteOutgoingEmail(),
			"cb_site_homepage" = "cbBlog",
			"cb_site_disable_blog" = "false",

			// Paging Defaults
			"cb_paging_maxrows" = "20",
			"cb_paging_bandgap" = "5",
			"cb_paging_maxentries" = "10",
			"cb_paging_maxRSSComments" = "10",

			// Gravatar
			"cb_gravatar_display" = "true",
			"cb_gravatar_rating" = "PG",

			// Dashboard Settings
			"cb_dashboard_recentEntries" = "5",
			"cb_dashboard_recentPages" = "5",
			"cb_dashboard_recentComments" = "5",

			// Comment Settings
			"cb_comments_whoisURL" = "http://whois.arin.net/ui/query.do?q",
			"cb_comments_maxDisplayChars" = "500",
			"cb_comments_enabled" = "true",
			"cb_comments_urltranslations" = "true",
			"cb_comments_moderation" = "true",
			"cb_comments_moderation_whitelist" = "true",
			"cb_comments_notify" = "true",
			"cb_comments_moderation_notify" = "true",
			"cb_comments_notifyemails" = "",
			"cb_comments_moderation_blacklist" = "",
			"cb_comments_moderation_blockedlist" = "",
			"cb_comments_captcha" = "true",

			// Mail Settings
			"cb_site_mail_server" = setup.getcb_site_mail_server(),
			"cb_site_mail_username" = setup.getcb_site_mail_username(),
			"cb_site_mail_password" = setup.getcb_site_mail_password(),
			"cb_site_mail_smtp" = setup.getcb_site_mail_smtp(),
			"cb_site_mail_tls" = setup.getcb_site_mail_tls(),
			"cb_site_mail_ssl" = setup.getcb_site_mail_ssl(),

			// Notifications
			"cb_notify_author" = "true",
			"cb_notify_entry"  = "true",
			"cb_notify_page"   = "true",

			// Site Layout
			"cb_site_layout" = "default",

			// RSS Feeds
			"cb_rss_maxEntries" = "10",
			"cb_rss_maxComments" = "10",
			"cb_rss_caching" = "true",
			"cb_rss_cachingTimeout" = "60",
			"cb_rss_cachingTimeoutIdle" = "15",
			"cb_rss_cacheName" = "Template",

			// Content Caching
			"cb_content_caching" = "true",
			"cb_entry_caching" = "true",
			"cb_customHTML_caching" = "true",
			"cb_content_cachingTimeout" = "60",
			"cb_content_cachingTimeoutIdle" = "15",
			"cb_content_cacheName" = "Template",

			// Global HTML
			"cb_html_beforeHeadEnd" = "",
			"cb_html_afterBodyStart" = "",
			"cb_html_beforeBodyEnd" = "",
			"cb_html_beforeContent" = "",
			"cb_html_afterContent" = "",
			"cb_html_beforeSideBar" = "",
			"cb_html_afterSideBar" = "",
			"cb_html_afterFooter" = "",
			"cb_html_preEntryDisplay" = "",
			"cb_html_postEntryDisplay" = "",
			"cb_html_preIndexDisplay" = "",
			"cb_html_postIndexDisplay" = "",
			"cb_html_preArchivesDisplay" = "",
			"cb_html_postArchivesDisplay" = "",
			"cb_html_preCommentForm" = "",
			"cb_html_postCommentForm" = "",
			"cb_html_prePageDisplay" = "",
			"cb_html_postPageDisplay" = "",

			// Media Manager
			"cb_media_directoryRoot" = expandPath("/contentbox/content"),
			"cb_media_createFolders" = "true",
			"cb_media_allowDelete" = "true",
			"cb_media_allowDownloads" = "true",
			"cb_media_allowUploads" = "true",
			"cb_media_acceptMimeTypes" = "",
			"cb_media_quickViewWidth" = "400",

			// Uploadify Integration
			"cb_media_uplodify_fileDesc" = "All Files",
			"cb_media_uplodify_fileExt" = "*.*;",
			"cb_media_uploadify_allowMulti" = "true",
			"cb_media_uploadify_sizeLimit" = "0",
			"cb_media_uploadify_customOptions" = "",

			// Search Settings
			"cb_search_adapter" = "contentbox.model.search.DBSearch",
			"cb_search_maxResults" = "20",

			// Site Maintenance
			"cb_site_maintenance_message" = "<h1>This site is down for maintenance.<br /> Please check back again soon.</h1>",
			"cb_site_maintenance" = "false"
		};

		// Create setting objects and save
		var aSettings = [];
		for(var key in settings){
			var props = {name=key,value=settings[key]};
			arrayAppend( aSettings, settingService.new(properties=props) );
		}

		settingService.saveAll( aSettings );
	}

	/**
	* Create Sample Data
	*/
	function createSampleData(required setup, required author){

		// create a few categories
		categoryService.createCategories("News, ColdFusion, ColdBox, ContentBox");

		// create some blog entries
		var entry = entryService.new(properties={
			title = "My first entry",
			slug  = "my-first-entry",
			publishedDate = now(),
			isPublished = true,
			allowComments = true,
			passwordProtection='',
			HTMLKeywords = "cool,first entry, contentbox",
			HTMLDescription = "The most amazing ContentBox blog entry in the world"
		});
		// version content
		entry.addNewContentVersion(content="Hey everybody, this is my first blog entry made from ContentBox.  Isn't this amazing!'",
								   changelog="Initial creation",
								   author=author);

		// good comment
		var comment = commentService.new(properties={
			content = "What an amazing blog entry, congratulations!",
			author = "Awesome Joe",
			authorIP = cgi.REMOTE_ADDR,
			authorEmail = "awesomejoe@gocontentbox.com",
			authorURL = "www.gocontentbox.com",
			isApproved = true
		});
		comment.setRelatedContent( entry );
		entry.addComment( comment );

		// nasty comment
		var comment = commentService.new(properties={
			content = "I am some bad words and bad comment not approved",
			author = "Bad Joe",
			authorIP = cgi.REMOTE_ADDR,
			authorEmail = "badjoe@gocontentbox.com",
			authorURL = "www.gocontentbox.com",
			isApproved = false
		});
		comment.setRelatedContent( entry );
		entry.addComment( comment );

		// save entry
		entryService.saveEntry( entry );

		// create a page
		var page = pageService.new(properties={
			title = "About",
			slug  = "about",
			publishedDate = now(),
			isPublished = true,
			allowComments = false,
			passwordProtection='',
			HTMLKeywords = "about, contentbox,coldfusion,coldbox",
			HTMLDescription = "The most amazing ContentBox page in the world",
			layout = "pages"
		});
		page.addNewContentVersion(content="<p>Hey welcome to my about page for ContentBox, isn't this great!</p><p>{{{CustomHTML slug='contentbox'}}}</p>",
								  changelog="First creation",
								  author=author);
		pageService.savePage( page );

		// create a custom HTML snippet.
		var customHTML = customHTMLService.new(properties={
			title = "ContactInfo",
			slug = "contentbox",
			description = "Our contact information",
			content = '<p style="text-align: center;">
	<a href="http://gocontentbox.org"><img alt="" src="/modules/contentbox/content/ContentBox_125.gif" style="width: 124px; height: 118px;" /></a></p>
<p style="text-align: center;">
	Created by <a href="http://www.ortussolutions.com">Ortus Solutions, Corp</a> and powered by <a href="http://coldbox.org">ColdBox Platform</a>.</p>'
		});
		customHTMLService.saveCustomHTML( customHTML );

	}

}
