#!/usr/bin/env python3

import os, argparse, pickle, sys, json
import jsonmerge
from string import Template

class StartupData(object):
	def __init__(self):
		self.__current_running_dir = os.path.dirname(os.path.abspath(__file__))
		self.__installation_dir = os.getcwd()
		self.__default_JSON = None
		self.__user_JSON = None

		self.find_default_file()
		self.read_defaults()

	def get_running_directory(self):
		return self.__current_running_dir

	def get_installation_directory(self):
		return self.__installation_dir

	def find_default_file(self):
		if os.path.isdir(self.__installation_dir):
			default_file=os.path.join(self.__installation_dir, 'defaultValues.json')
			if os.path.exists(default_file):
				self.__default_JSON = open(default_file, 'r')

	def read_defaults(self):
		if self.__default_JSON != None:
			try:
				if hasattr(self.__default_JSON, 'read'):
					self.__default_JSON = json.load(self.__default_JSON)
			except IOError:
				tb = sys.exc_info()[2]
				raise RuntimeError("Unable to read defaults for Docker Image Management!").with_traceback(tb)

	def user_definitions(self, userfile):
		if userfile == None or not os.path.exists(userfile):
			return

		self.__user_JSON = open(userfile, 'r')

	def generate_applications(self):
		if self.__user_JSON != None and self.__default_JSON != None:
			#schema = { "properties": { "applications": { "mergeStrategy" : "append" }}}
			#jsonMerger = Merger(schema)
			try:
				if hasattr(self.__user_JSON, 'read'):
					self.__user_JSON = json.load(self.__user_JSON)
				conglomeration = jsonmerge.merge( self.__user_JSON, self.__default_JSON )
				return conglomeration
			except IOError:
				tb = sys.exc_info()[2]
				raise RuntimeError("Unable to user addons for Docker Image Management!").with_traceback(tb)
		else:
			if self.__user_JSON == None and self.__default_JSON != None:
				return self.__default_JSON

			if self.__user_JSON != None and self.__default_JSON == None:
				if hasattr(self.__user_JSON, 'read'):
					self.__user_JSON = json.load(self.__user_JSON)
				return self.__user_JSON
			return '{}'

	def print(self):
		print("Current Running Directory      : " + self.__current_running_dir)
		print("Current Installation Directory : " + self.__installation_dir)
		print("Default JSON (decoded)         : " + str(self.__default_JSON != None) )
		print("User JSON (decoded)            : " + str(self.__user_JSON != None) )



class ApplicationDockerImageData(object):

	def __init__(self, apptype):
		self.__application_type = apptype
		self.__application_version = -1.0
		self.__environment_variables = {}
		self.__application_links = {}
		self.__docker_image_name = None
		self.__docker_image_version = -1.0
		self.__download_src_url = None
		self.__dependent_apps = []
		self.__docker_code_snippets = {}

	def add_application_link(self, source, target):
		self.__application_links[source] = target

	def remove_application_link(self, target):
		for key in self.__application_links.keys():
			if target == self.__application_links[key]:
				del self.__application_links[key]
				return

	def add_environment_setting(self, envname, envvalue):
		if envname != None and envname != '':
			if envvalue != None and envvale != '':
				self.__environment_variables[envname] = envvalue

	def remove_environment_setting(self, envname):
		if envname != None and envname != '':
			for key in self.__environment_variables.keys():
				if envname == envname:
					del self.__environment_variables[envname]
					return

	def add_dependent_app(self, appname):
		if appname == None:
			return
		if appname in self.__dependent_apps:
			return
		self.__dependent_apps.append(appname)

	def process_JSON_data(self, JSONdata):
		if JSONdata == None:
			return
		if "applications" in JSONdata:
			if self.__application_type in JSONdata["applications"]:
				JSONsubsection = JSONdata["applications"][appname]
				if "dependent_apps" in JSONsubsection:
					self.__dependent_apps = JSONsubsection["dependent_apps"]
				if "download_url" in JSONsubsection:
					self.__download_src_url = JSONsubsection["download_url"]
				if "links" in JSONsubsection:
					if "link" in JSONsubsection["links"]:
						self.__application_links = JSONsubsection["links"]["link"]
				if "environ_vars" in JSONsubsection:
					if "environ_var" in JSONsubsection["environ_vars"]:
						for block in JSONsubsection["environ_vars"]["environ_var"]:
							self.__environment_variables[block["name"]] = block["value"]

		if "default_application_versions" in JSONdata:
			self.__application_version = JSONdata["default_application_versions"][(self.__application_type + "_version").upper()]

		return self;

	def print(self):
		print("Dependent Applications           : " + str(self.__dependent_apps))
		print("Application Type                 : " + str(self.__application_type))
		print("Application Version              : " + str(self.__application_version))
		print("Docker Image Name                : " + str(self.__docker_image_name))
		print("Docker Image Version             : " + str(self.__docker_image_version))
		print("Source Download URL              : " + str(self.__download_src_url))
		print("Application Links                : " + str(self.__application_links))
		print("Application Environment Settings : " + str(self.__environment_variables))



def pp_json(json_thing, sort=True, indents=4):
    if type(json_thing) is str:
        print(json.dumps(json.loads(json_thing), sort_keys=sort, indent=indents))
    else:
        print(json.dumps(json_thing, sort_keys=sort, indent=indents))
    return None

def dump(obj):
   for attr in dir(obj):
       if hasattr( obj, attr ):
           print( "obj.%s = %s" % (attr, getattr(obj, attr)))

def process_cmdline_inputs():
	parser = argparse.ArgumentParser()

	parser.add_argument("-d","--dryrun", help="Build docker file(s) but do NOT initiate docker engine build.", action="store_true")
	parser.add_argument("--dockerdir", help="Define toplevel of tree representing docker files.")
	parser.add_argument("--container-name", help="Container version to associate to docker build.")
	parser.add_argument("--container-version", help="Container repository name for docker build.")
	parser.add_argument("--single", help="Allow for a single builds for any applications to be made into separate docker files,", action="store_true")
	parser.add_argument("--composite", help="Allow for a composite dockerfile for all applications to be assembled,", action="store_true")
	parser.add_argument("--multi-stage", help="Allow for a multistage dockerfile for all applications to be assembled.", action="store_true")
	parser.add_argument("-v", "--verbose", help="Turn on debugging output while processing.", action="store_true")
	parser.add_argument("-e", "--env", help="Environment setting to include into docker build image.")
	parser.add_argument("-p", "--package", help="Ubuntu package to include into upgrade of basis docker image.  This option can be used more than once or multiple packages can be associated per calling instance (in quotes).")

	parser.parse_args()
	return parser

startupInformation = StartupData()
startupInformation.user_definitions(os.path.join(startupInformation.get_installation_directory(),'userValues.json'))

apps = []
combined_data = startupInformation.generate_applications()
discovered_apps = list(combined_data["applications"].keys())

for appname in discovered_apps:
	appDataBlock = ApplicationDockerImageData(appname)
	apps.append(appDataBlock.process_JSON_data(combined_data))
	apps[len(apps) - 1].print()









#parser = process_cmdline_inputs

#dump(startupInformation)

