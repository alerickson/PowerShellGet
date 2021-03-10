﻿// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.
using System;
using System.Collections.Generic;
using static System.Environment;
using System.IO;
using System.Linq;
using System.Management.Automation;
using System.Runtime.InteropServices;
using System.Threading;
using System.Collections;
using MoreLinq;
using MoreLinq.Extensions;
using static Microsoft.PowerShell.PowerShellGet.PSResourceInfo;
using static Microsoft.PowerShell.PowerShellGet.PSResourceInfo.VersionInfo;
using NuGet.Versioning;


namespace Microsoft.PowerShell.PowerShellGet.Cmdlets
{
    /// <summary>
    /// Find helper class
    /// </summary>
    class GetHelper : PSCmdlet
    {
        private CancellationToken cancellationToken;
        private readonly PSCmdlet cmdletPassedIn;
        private string programFilesPath;
        private string myDocumentsPath;
        public static readonly string OsPlatform = System.Runtime.InteropServices.RuntimeInformation.OSDescription;

        public GetHelper(CancellationToken cancellationToken, PSCmdlet cmdletPassedIn)
        {
            this.cancellationToken = cancellationToken;
            this.cmdletPassedIn = cmdletPassedIn;
        }

        public IEnumerable<PSResourceInfo> ProcessGetParams(string[] name, string version, string path)
        {
            List<string> dirsToSearch = new List<string>();

            if (path != null)
            {
                cmdletPassedIn.WriteDebug(string.Format("Provided path is: '{0}'", path));
                dirsToSearch.AddRange(Directory.GetDirectories(path).ToList());
            }
            else
            {
                string psModulePath = Environment.GetEnvironmentVariable("PSModulePath");
                string[] modulePaths = psModulePath.Split(';');
#if NET472
                programFilesPath = System.IO.Path.Combine(Environment.GetFolderPath(SpecialFolder.ProgramFiles), "WindowsPowerShell");
                myDocumentsPath = System.IO.Path.Combine(Environment.GetFolderPath(SpecialFolder.MyDocuments), "WindowsPowerShell");
#else
                // If PS6+ on Windows
                if (RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
                {
                    myDocumentsPath = System.IO.Path.Combine(Environment.GetFolderPath(SpecialFolder.MyDocuments), "PowerShell");
                    programFilesPath = System.IO.Path.Combine(Environment.GetFolderPath(SpecialFolder.ProgramFiles), "PowerShell");
                }
                else
                {
                    // Paths are the same for both Linux and MacOS
                    myDocumentsPath = System.IO.Path.Combine(Environment.GetFolderPath(SpecialFolder.LocalApplicationData), "powershell");
                    programFilesPath = System.IO.Path.Combine("/usr", "local", "share", "powershell");
                }
#endif
                cmdletPassedIn.WriteDebug(string.Format("Current user scope path: '{0}'", myDocumentsPath));
                cmdletPassedIn.WriteDebug(string.Format("All users scope path: '{0}'", programFilesPath));

                // will search first in PSModulePath, then will search in default paths
                foreach (string modulePath in modulePaths)
                {
                    dirsToSearch.AddRange(Directory.GetDirectories(modulePath).ToList());
                }
                
                string pfModulesPath = System.IO.Path.Combine(programFilesPath, "Modules");
                if (Directory.Exists(pfModulesPath))
                {
                    dirsToSearch.AddRange(Directory.GetDirectories(pfModulesPath).ToList());
                }
                string mdModulesPath = System.IO.Path.Combine(myDocumentsPath, "Modules");
                if (Directory.Exists(mdModulesPath))
                {
                    dirsToSearch.AddRange(Directory.GetDirectories(mdModulesPath).ToList());
                }
                string pfScriptsPath = System.IO.Path.Combine(programFilesPath, "Scripts", "InstalledScriptInfos");
                if (Directory.Exists(pfScriptsPath))
                {
                    dirsToSearch.AddRange(Directory.GetFiles(pfScriptsPath).ToList());
                }
                string mdScriptsPath = System.IO.Path.Combine(myDocumentsPath, "Scripts", "InstalledScriptInfos");
                if (Directory.Exists(mdScriptsPath))
                {
                    dirsToSearch.AddRange(Directory.GetFiles(mdScriptsPath).ToList());
                }
                
                dirsToSearch = dirsToSearch.Distinct().ToList();
            }

            //            dirsToSearch = new List<string>();
            //            dirsToSearch.AddRange(Directory.GetDirectories("C:\\Program Files\\WindowsPowerShell\\Modules").ToList());

            dirsToSearch.ForEach(dir => cmdletPassedIn.WriteDebug(string.Format("All directories to search: '{0}'", dir)));
            
            if (name != null && !name[0].Equals("*"))
            {
                List<string> nameLowerCased = new List<string>();
                List<string> scriptXMLnames = new List<string>();
                Array.ForEach(name, n => nameLowerCased.Add(n.ToLower()));
                Array.ForEach(name, n => scriptXMLnames.Add((n + "_InstalledScriptInfo.xml").ToLower()));

                dirsToSearch = dirsToSearch.FindAll(p => (nameLowerCased.Contains(new DirectoryInfo(p).Name.ToLower())
                    || scriptXMLnames.Contains((System.IO.Path.GetFileName(p)).ToLower())));

                cmdletPassedIn.WriteDebug(dirsToSearch.Any().ToString());
            }

            // try to parse into a specific NuGet version
            VersionRange versionRange = null;
            if (version != null)
            {
                NuGetVersion.TryParse(version, out NuGetVersion specificVersion);

                if (specificVersion != null)
                {
                    // check if exact version
                    versionRange = new VersionRange(specificVersion, true, specificVersion, true, null, null);
                    cmdletPassedIn.WriteDebug(string.Format("A specific version, '{0}', is specified", versionRange.ToString()));
                }
                else
                {
                    // check if version range
                    versionRange = VersionRange.Parse(version);
                    cmdletPassedIn.WriteDebug(string.Format("A version range, '{0}', is specified", versionRange.ToString()));
                }
            }

            List<string> installedPkgsToReturn = new List<string>();
            
            // check if the version specified is within a version range
            if (versionRange != null)
            {
                foreach (string pkgPath in dirsToSearch)
                {
                    cmdletPassedIn.WriteDebug(string.Format("Searching through package path: '{0}'", pkgPath));
                    string[] versionsDirs = Directory.GetDirectories(pkgPath);

                    foreach (string versionPath in versionsDirs)
                    {
                        cmdletPassedIn.WriteDebug(string.Format("Searching through package version path: '{0}'", versionPath));
                        NuGetVersion dirAsNugetVersion;
                        DirectoryInfo dirInfo = new DirectoryInfo(versionPath);
                        NuGetVersion.TryParse(dirInfo.Name, out dirAsNugetVersion);
                        cmdletPassedIn.WriteDebug(string.Format("Directory parsed as NuGet version: '{0}'", dirAsNugetVersion));

                        if (versionRange.Satisfies(dirAsNugetVersion))
                        {
                            // just search scripts paths
                            if (pkgPath.ToLower().Contains("Scripts"))
                            {
                                if (File.Exists(pkgPath))
                                {
                                    installedPkgsToReturn.Add(pkgPath);
                                }
                            }
                            else
                            {
                                // modules paths
                                versionsDirs = Directory.GetDirectories(pkgPath);
                                cmdletPassedIn.WriteDebug(string.Format("Getting sub directories from : '{0}'", pkgPath));

                                // check if the pkg path actually has version sub directories
                                if (versionsDirs.Length != 0)
                                {
                                    Array.Sort(versionsDirs, StringComparer.OrdinalIgnoreCase);
                                    Array.Reverse(versionsDirs);

                                    string pkgXmlFilePath = System.IO.Path.Combine(versionsDirs.First(), "PSGetModuleInfo.xml");

                                    // TODO:  check if this xml file exists, if it doesn't check if it exists in a previous version
                                    cmdletPassedIn.WriteDebug(string.Format("Found module XML: '{0}'", pkgXmlFilePath));

                                    installedPkgsToReturn.Add(pkgXmlFilePath);
                                }
                            }

                            installedPkgsToReturn.Add(versionPath);
                        }
                    }
                }
            }
            else
            {
                cmdletPassedIn.WriteDebug("No version provided-- check each path for the requested package");
                // if no version is specified, just get the latest version
                foreach (string pkgPath in dirsToSearch)
                {
                    cmdletPassedIn.WriteDebug(string.Format("Searching through package path: '{0}'", pkgPath));

                    // just search scripts paths
                    if (pkgPath.ToLower().Contains("scripts"))
                    {
                        if (File.Exists(pkgPath))
                        {
                            installedPkgsToReturn.Add(pkgPath);
                        }
                    }
                    else
                    {
                        // search modules paths
                        string[] versionsDirs = new string[0];

                        versionsDirs = Directory.GetDirectories(pkgPath);

                        // Check if the pkg path actually has version sub directories.
                        if (versionsDirs.Length != 0)
                        {
                            Array.Sort(versionsDirs, StringComparer.OrdinalIgnoreCase);
                            Array.Reverse(versionsDirs);

                            string pkgXmlFilePath = System.IO.Path.Combine(versionsDirs.First(), "PSGetModuleInfo.xml");

                            // TODO:  check if this xml file exists, if it doesn't check if it exists in a previous version
                            cmdletPassedIn.WriteDebug(string.Format("Found package XML: '{0}'", pkgXmlFilePath));
                            installedPkgsToReturn.Add(pkgXmlFilePath);
                        }
                    }
                }
            }

            IEnumerable<object> flattenedPkgs =  FlattenExtension.Flatten(installedPkgsToReturn);
            List<PSResourceInfo> foundInstalledPkgs = new List<PSResourceInfo>();

            foreach (string xmlFilePath in flattenedPkgs)
            {
                cmdletPassedIn.WriteDebug(string.Format("Reading package metadata from: '{0}'", xmlFilePath));

                // Open xml and read metadata from it     
                if (File.Exists(xmlFilePath))
                {
                    PSObject deserializedObj = null;
                    using (StreamReader sr = new StreamReader(xmlFilePath))
                    {
                        string text = sr.ReadToEnd();
                        deserializedObj = (PSObject) PSSerializer.Deserialize(text);
                    };
                    
                    PSResourceInfo pkgAsPSObject = new PSResourceInfo();
                    
                    if (deserializedObj != null)
                    {
                        try
                        {
                            LanguagePrimitives.TryConvertTo(
                                (deserializedObj.Properties["Name"] != null ? deserializedObj.Properties["Name"].Value?.ToString() : String.Empty), out string nameProp);
                            pkgAsPSObject.Name = nameProp;
                        }
                        catch (Exception e)
                        {
                            string exMessage = String.Format("NAME error: " + e.Message);
                            ParseException ex = new ParseException(exMessage);
                            var ErrorParsingName = new ErrorRecord(ex, "ErrorParsingName", ErrorCategory.ParserError, null);
                            cmdletPassedIn.WriteError(ErrorParsingName);
                        }

                        try
                        {
                            System.Version.TryParse(deserializedObj.Properties["Version"].Value?.ToString(), out System.Version versionProp);
                            pkgAsPSObject.Version = versionProp;
                        }
                        catch (Exception e)
                        {
                            string exMessage = String.Format("VERSION error: " + e.Message);
                            ParseException ex = new ParseException(exMessage);
                            var ErrorParsingVersion = new ErrorRecord(ex, "ErrorParsingVersion", ErrorCategory.ParserError, null);
                            cmdletPassedIn.WriteError(ErrorParsingVersion);
                        }

                        //check this one
                        pkgAsPSObject.Type = string.Equals(deserializedObj.Properties["Type"].Value?.ToString(), "Module", StringComparison.InvariantCultureIgnoreCase) ? ResourceType.Module : ResourceType.Script;
                       
                        try
                        {
                            LanguagePrimitives.TryConvertTo(
                                (deserializedObj.Properties["Description"] != null ? deserializedObj.Properties["Description"].Value?.ToString() : String.Empty), out string descriptionProp);
                            pkgAsPSObject.Description = descriptionProp;
                        }
                        catch (Exception e)
                        {
                            string exMessage = String.Format("DESCRIPTION error: " + e.Message);
                            ParseException ex = new ParseException(exMessage);
                            var ErrorParsingDescription = new ErrorRecord(ex, "ErrorParsingDescription", ErrorCategory.ParserError, null);
                            cmdletPassedIn.WriteError(ErrorParsingDescription);
                        }
                        
                        try
                        {
                            LanguagePrimitives.TryConvertTo(
                                (deserializedObj.Properties["Author"] != null ? deserializedObj.Properties["Author"].Value?.ToString() : String.Empty), out string authorProp);
                            pkgAsPSObject.Author = authorProp;
                        }
                        catch (Exception e)
                        {
                            string exMessage = String.Format("AUTHOR error: " + e.Message);
                            ParseException ex = new ParseException(exMessage);
                            var ErrorParsingAuthor = new ErrorRecord(ex, "ErrorParsingAuthor", ErrorCategory.ParserError, null);
                            cmdletPassedIn.WriteError(ErrorParsingAuthor);
                        }

                        try
                        {
                            LanguagePrimitives.TryConvertTo(
                                    (deserializedObj.Properties["CompanyName"] != null ? deserializedObj.Properties["CompanyName"].Value?.ToString() : String.Empty), out string companyNameProp);
                            pkgAsPSObject.CompanyName = companyNameProp;
                        }
                        catch (Exception e)
                        {
                            string exMessage = String.Format("COMPANY NAME error: " + e.Message);
                            ParseException ex = new ParseException(exMessage);
                            var ErrorParsingCompanyName = new ErrorRecord(ex, "ErrorParsingCompanyName", ErrorCategory.ParserError, null);
                            cmdletPassedIn.WriteError(ErrorParsingCompanyName);
                        }

                        try
                        {
                            LanguagePrimitives.TryConvertTo(
                                (deserializedObj.Properties["Copyright"] != null ? deserializedObj.Properties["Copyright"].Value?.ToString() : String.Empty), out string copyrightProp);
                            pkgAsPSObject.Copyright = copyrightProp;
                        }
                        catch (Exception e)
                        {
                            string exMessage = String.Format("COPYRIGHT error: " + e.Message);
                            ParseException ex = new ParseException(exMessage);
                            var ErrorParsingCopyright = new ErrorRecord(ex, "ErrorParsingCopyright", ErrorCategory.ParserError, null);
                            cmdletPassedIn.WriteError(ErrorParsingCopyright);
                        }
                        
                        try
                        {
                            LanguagePrimitives.TryConvertTo(
                                (deserializedObj.Properties["PublishedDate"] != null ? (DateTime?)(((deserializedObj.Properties["PublishedDate"]).Value) as PSObject).Properties["DateTime"].Value : null), out DateTime publishedDateProp);
                            pkgAsPSObject.PublishedDate = publishedDateProp;
                        }
                        catch (Exception e)
                        {
                            try
                            {
                                LanguagePrimitives.TryConvertTo(
                                    (deserializedObj.Properties["PublishedDate"] != null ? (DateTime?) deserializedObj.Properties["PublishedDate"].Value : null), out DateTime? publishedDateProp);
                                pkgAsPSObject.PublishedDate = publishedDateProp;
                            }
                            catch (Exception e2)
                            {
                                string exMessage = String.Format("PUBLISHED DATE error: " + e.Message);
                                ParseException ex = new ParseException(exMessage);
                                var ErrorParsingPublishedDate = new ErrorRecord(ex, "ErrorParsingPublishedDate", ErrorCategory.ParserError, null);
                                cmdletPassedIn.WriteError(ErrorParsingPublishedDate);
                            }
                        }

                        try
                        {
                            LanguagePrimitives.TryConvertTo(
                                (deserializedObj.Properties["InstalledDate"] != null ? (DateTime?) (deserializedObj.Properties["InstalledDate"].Value as PSObject).Properties["Date"].Value : null), out DateTime? installedDateProp);
                            pkgAsPSObject.InstalledDate = installedDateProp;
                        }
                        catch (Exception e)
                        {
                            string exMessage = String.Format("INSTALLED DATE error: " + e.Message);
                            ParseException ex = new ParseException(exMessage);
                            var ErrorParsingInstalledDate = new ErrorRecord(ex, "ErrorParsingInstalledDate", ErrorCategory.ParserError, null);
                            cmdletPassedIn.WriteError(ErrorParsingInstalledDate);
                        }
                        
                        try
                        {
                            LanguagePrimitives.TryConvertTo(
                                (deserializedObj.Properties["UpdatedDate"] != null ? (DateTime?)deserializedObj.Properties["UpdatedDate"].Value : null), out DateTime updatedDateProp);
                            pkgAsPSObject.UpdatedDate = updatedDateProp;
                        }
                        catch (Exception e)
                        {
                            string exMessage = String.Format("UPDATED DATE error: " + e.Message);
                            ParseException ex = new ParseException(exMessage);
                            var ErrorParsingUpdatedDate = new ErrorRecord(ex, "ErrorParsingUpdatedDate", ErrorCategory.ParserError, null);
                            cmdletPassedIn.WriteError(ErrorParsingUpdatedDate);
                        }

                        try
                        {
                            LanguagePrimitives.TryConvertTo(
                                (deserializedObj.Properties["LicenseUri"] != null ? (Uri)deserializedObj.Properties["LicenseUri"].Value : null), out Uri licenseUriProp);
                            pkgAsPSObject.LicenseUri = licenseUriProp;
                        }
                        catch (Exception e)
                        {
                            string exMessage = String.Format("LICENSE URI error: " + e.Message);
                            ParseException ex = new ParseException(exMessage);
                            var ErrorParsingLicenseUri = new ErrorRecord(ex, "ErrorParsingLicenseUri", ErrorCategory.ParserError, null);
                            cmdletPassedIn.WriteError(ErrorParsingLicenseUri);
                        }
                        
                        try
                        {
                            LanguagePrimitives.TryConvertTo(
                                (deserializedObj.Properties["ProjectUri"] != null ? (Uri)deserializedObj.Properties["ProjectUri"].Value : null), out Uri projectUriProp);
                            pkgAsPSObject.ProjectUri = projectUriProp;
                        }
                        catch (Exception e)
                        {
                            string exMessage = String.Format("PROJECT URI error: " + e.Message);
                            ParseException ex = new ParseException(exMessage);
                            var ErrorParsingProjectUri = new ErrorRecord(ex, "ErrorParsingProjectUri", ErrorCategory.ParserError, null);
                            cmdletPassedIn.WriteError(ErrorParsingProjectUri);
                        }

                        try
                        {
                            LanguagePrimitives.TryConvertTo(
                                 (deserializedObj.Properties["IconUri"] != null ? (Uri)deserializedObj.Properties["IconUri"].Value : null), out Uri iconUriProp);
                            pkgAsPSObject.IconUri = iconUriProp;
                        }
                        catch (Exception e)
                        {
                            string exMessage = String.Format("ICON URI error: " + e.Message);
                            ParseException ex = new ParseException(exMessage);
                            var ErrorParsingIconUri = new ErrorRecord(ex, "ErrorParsingIconUri", ErrorCategory.ParserError, null);
                            cmdletPassedIn.WriteError(ErrorParsingIconUri);
                        }

                        try
                        {
                            System.Version.TryParse(
                                (deserializedObj.Properties["PowerShellGetFormatVersion"] != null ? deserializedObj.Properties["PowerShellGetFormatVersion"].Value?.ToString() : String.Empty),
                                out System.Version powerShellGetFormatVersionProp);
                            pkgAsPSObject.PowerShellGetFormatVersion = powerShellGetFormatVersionProp;
                        }
                        catch (Exception e)
                        {
                            string exMessage = String.Format("POWERSHELLGET FORMAT VERSION error: " + e.Message);
                            ParseException ex = new ParseException(exMessage);
                            var ErrorParsingPowerShellGetFormatVersion = new ErrorRecord(ex, "ErrorParsingPowerShellGetFormatVersion", ErrorCategory.ParserError, null);
                            cmdletPassedIn.WriteError(ErrorParsingPowerShellGetFormatVersion);
                        }

                        try
                        {
                            LanguagePrimitives.TryConvertTo(
                                   (deserializedObj.Properties["ReleaseNotes"] != null ? deserializedObj.Properties["ReleaseNotes"].Value?.ToString() : null), out string releaseNotesProp);
                            pkgAsPSObject.ReleaseNotes = releaseNotesProp;
                        }
                        catch (Exception e)
                        {
                            string exMessage = String.Format("RELEASE NOTES error: " + e.Message);
                            ParseException ex = new ParseException(exMessage);
                            var ErrorParsingReleaseNotes = new ErrorRecord(ex, "ErrorParsingReleaseNotes", ErrorCategory.ParserError, null);
                            cmdletPassedIn.WriteError(ErrorParsingReleaseNotes);
                        }

                        try
                        {
                            LanguagePrimitives.TryConvertTo(
                                (deserializedObj.Properties["Repository"] != null ? deserializedObj.Properties["Repository"].Value?.ToString() : null), out string repositoryProp);
                            pkgAsPSObject.Repository = repositoryProp;
                        }
                        catch (Exception e)
                        {
                            string exMessage = String.Format("REPOSITORY error: " + e.Message);
                            ParseException ex = new ParseException(exMessage);
                            var ErrorParsingRepository = new ErrorRecord(ex, "ErrorParsingRepository", ErrorCategory.ParserError, null);
                            cmdletPassedIn.WriteError(ErrorParsingRepository);
                        }

                        try
                        {
                            bool.TryParse(deserializedObj.Properties["IsPrerelease"] != null ? deserializedObj.Properties["IsPrerelease"].Value?.ToString() : null, out bool isPrerelease);
                            pkgAsPSObject.IsPrerelease = isPrerelease;
                        }
                        catch (Exception e)
                        {
                            string exMessage = String.Format("IS PRERELEASE error: " + e.Message);
                            ParseException ex = new ParseException(exMessage);
                            var ErrorParsingIsPrerelease = new ErrorRecord(ex, "ErrorParsingIsPrerelease", ErrorCategory.ParserError, null);
                            cmdletPassedIn.WriteError(ErrorParsingIsPrerelease);
                        }
                        
                        try
                        {

                            string[] emptyArr = new string[] { };

                            LanguagePrimitives.TryConvertTo(
                                (deserializedObj.Properties["Tags"] != null ? (string[]) (deserializedObj.Properties["Tags"].Value.ToString()).Split(' ') : emptyArr), out string[] tagsProp);
                            pkgAsPSObject.Tags = tagsProp;
                        }
                        catch (Exception e)
                        {
                            string exMessage = String.Format("TAGS error: " + e.Message);
                            ParseException ex = new ParseException(exMessage);
                            var ErrorParsingTags = new ErrorRecord(ex, "ErrorParsingTags", ErrorCategory.ParserError, null);
                            cmdletPassedIn.WriteError(ErrorParsingTags);
                        }

                        try
                        {                       
                            ArrayList listOfDependencies = ((deserializedObj.Properties["Dependencies"].Value as PSObject).BaseObject as ArrayList);
                            
                            Dictionary<string, VersionInfo> depDictionary = new Dictionary<string, VersionInfo>(); 


                            foreach (PSObject dependency in listOfDependencies)
                            {                                
                                Hashtable depHash = dependency.BaseObject as Hashtable;
                                VersionType versionType = VersionType.Unknown;
                                System.Version versionNum = null;

                                if (depHash["MinimumVersion"] != null)
                                {
                                    versionType = VersionType.MinimumVersion;
                                    System.Version.TryParse(depHash["MinimumVersion"].ToString(), out versionNum);
                                }
                                if (depHash["RequiredVersion"] != null)
                                {
                                    versionType = VersionType.RequiredVersion;
                                    System.Version.TryParse(depHash["RequiredVersion"].ToString(), out versionNum);
                                }
                                if (depHash["MaximumVersion"] != null)
                                {
                                    versionType = VersionType.MaximumVersion;
                                    System.Version.TryParse(depHash["MaximumVersion"].ToString(), out versionNum);
                                }
                                VersionInfo versionInfo = new VersionInfo(versionType, versionNum);
                               
                                depDictionary.Add(depHash["Name"].ToString(), versionInfo);
                            }

                            pkgAsPSObject.Dependencies = depDictionary;
                        }
                        catch (Exception e)
                        {
                            string exMessage = String.Format("DEPENDENCIES error: " + e.Message);
                            ParseException ex = new ParseException(exMessage);
                            var ErrorParsingDependencies = new ErrorRecord(ex, "ErrorParsingDependencies", ErrorCategory.ParserError, null);
                            cmdletPassedIn.WriteError(ErrorParsingDependencies);
                        }

                        try
                        {
                            Hashtable includesHash = ((deserializedObj.Properties["Includes"].Value as PSObject).BaseObject) as Hashtable;

                            pkgAsPSObject.Commands = (ArrayList) (includesHash["Command"] as PSObject).BaseObject;
                            pkgAsPSObject.DscResources = (ArrayList) (includesHash["DscResource"] as PSObject).BaseObject;
                            pkgAsPSObject.Functions = (ArrayList) (includesHash["Function"] as PSObject).BaseObject;
                            pkgAsPSObject.Cmdlets = (ArrayList) (includesHash["Cmdlet"] as PSObject).BaseObject;
                        }
                        catch (Exception e)
                        {
                            string exMessage = String.Format("INCLUDES error: " + e.Message);
                            ParseException ex = new ParseException(exMessage);
                            var ErrorParsingIncludes = new ErrorRecord(ex, "ErrorParsingIncludes", ErrorCategory.ParserError, null);
                            cmdletPassedIn.WriteError(ErrorParsingIncludes);
                        }
                        
                        try
                        {
                            LanguagePrimitives.TryConvertTo(
                                (deserializedObj.Properties["AdditionalMetadata"] != null ? (string) deserializedObj.Properties["AdditionalMetadata"].Value.ToString() : string.Empty), out string additionalMetadataProp);
                            pkgAsPSObject.AdditionalMetadata = additionalMetadataProp;
                        }
                        catch (Exception e)
                        {
                            string exMessage = String.Format("ADDITIONAL METADATA error: " + e.Message);
                            ParseException ex = new ParseException(exMessage);
                            var ErrorParsingAdditionalMetadata = new ErrorRecord(ex, "ErrorParsingAdditionalMetadata", ErrorCategory.ParserError, null);
                            cmdletPassedIn.WriteError(ErrorParsingAdditionalMetadata);
                        }
                        
                        try
                        {
                            LanguagePrimitives.TryConvertTo(
                                (deserializedObj.Properties["InstalledLocation"] != null ? (string)deserializedObj.Properties["InstalledLocation"].Value : string.Empty), out string installedLocationProp);
                            pkgAsPSObject.InstalledLocation = installedLocationProp;
                        }
                        catch (Exception e)
                        {
                            string exMessage = String.Format("ADDITIONAL METADATA error: " + e.Message);
                            ParseException ex = new ParseException(exMessage);
                            var ErrorParsingAdditionalMetadata = new ErrorRecord(ex, "ErrorParsingAdditionalMetadata", ErrorCategory.ParserError, null);
                            cmdletPassedIn.WriteError(ErrorParsingAdditionalMetadata);
                        }

                        yield return pkgAsPSObject;
                    }
                }
            }
        }
    }
}
