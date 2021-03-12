
using System;
using System.Collections;
using System.Collections.Generic;

namespace Microsoft.PowerShell.PowerShellGet
{
    public enum ResourceType
    {
        Module,
        Script
    }


    public class PSResourceInfo
    {
        public string Name { get; set; }
        public System.Version Version { get; set; }
        public ResourceType Type { get; set; }    
        public string Description { get; set; }
        public string Author { get; set; }
        public string CompanyName { get; set; }
        public string Copyright { get; set; }
        public DateTime? PublishedDate { get; set; }
        public DateTime? InstalledDate { get; set; }
        public DateTime? UpdatedDate { get; set; }
        public Uri LicenseUri { get; set; }
        public Uri ProjectUri { get; set; }
        public Uri IconUri { get; set; }
        public System.Version PowerShellGetFormatVersion { get; set; }
        public string ReleaseNotes { get; set; }
        public string Repository { get; set; }
        public bool IsPrerelease { get; set; }
        public string[] Tags { get; set; }          
        public Dictionary<string, VersionInfo> Dependencies { get; set; }
        internal string AdditionalMetadata { get; set; }
        public ArrayList Commands { get; set; }
        public ArrayList Cmdlets { get; set; }
        public ArrayList DscResources { get; set; }
        public ArrayList Functions { get; set; }
        public string InstalledLocation { get; set; }


        public struct VersionInfo
        {
            public VersionInfo(VersionType versionType, System.Version versionNum)
            {
                this.versionType = versionType;
                this.versionNum = versionNum;
            }

            public VersionType versionType { get; }
            public System.Version versionNum { get; }

            public override string ToString() => $"{versionType}: {versionNum}";
            
            public enum VersionType
            {
                Unknown,
                MinimumVersion,
                RequiredVersion,
                MaximumVersion
            }
        }
    }
}