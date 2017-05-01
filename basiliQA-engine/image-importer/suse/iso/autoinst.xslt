<?xml version="1.0"?>
<!--
  autoinst.xslt
  basiliQA images importer
  Style sheet to adjust autoyast control file

  Copyright (C) 2015,2016 SUSE LLC

  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, version 2.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License along
  with this program; if not, write to the Free Software Foundation, Inc.,
  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
-->
<xsl:stylesheet xmlns:y="http://www.suse.com/1.0/yast2ns"
                xmlns:config="http://www.suse.com/1.0/configns"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns="http://www.suse.com/1.0/yast2ns"
                version="2.0">

<xsl:output method="xml" indent="yes" cdata-section-elements="source" />

<xsl:param name="arch" select="'UNDEFINED'" />
<xsl:param name="hostname" select="'UNDEFINED'" />
<xsl:param name="fips" select="'UNDEFINED'" />
<xsl:param name="graphical" select="'UNDEFINED'" />
<xsl:param name="onlinerepo" select="'UNDEFINED'" />
<xsl:param name="updaterepo" select="'UNDEFINED'" />

<xsl:template match="/y:profile/y:add-on/y:add_on_products">
  <xsl:element name="add_on_products">
    <xsl:attribute name="config:type"> <xsl:text>list</xsl:text> </xsl:attribute>
    <xsl:if test="$updaterepo and not(contains($updaterepo, 'SLE-SERVER/11'))">
      <xsl:element name="listentry">
        <xsl:element name="media_url">
          <!-- $updaterepo without the name of the .repo file (the part after last '/') -->
          <xsl:value-of select="substring($updaterepo, 1, index-of(string-to-codepoints($updaterepo), string-to-codepoints('/'))[last()] - 1)" />
        </xsl:element>
        <xsl:element name="product">
          <xsl:text>Updates</xsl:text>
        </xsl:element>
        <xsl:element name="alias">
          <xsl:text>Updates</xsl:text>
        </xsl:element>
        <xsl:element name="product_dir">
          <xsl:text>/</xsl:text>
        </xsl:element>
      </xsl:element>
    </xsl:if>
  </xsl:element>
</xsl:template>

<xsl:template match="/y:profile/y:bootloader/y:global/y:append/text()">
  <xsl:value-of select="." />
  <xsl:if test="$fips = 'yes'">
    <xsl:text> fips=1</xsl:text>
  </xsl:if>
</xsl:template>

<xsl:template match="/y:profile/y:networking/y:dns/y:hostname/text()">
  <xsl:value-of select="$hostname" />
</xsl:template>

<xsl:template match="/y:profile/y:runlevel/y:default/text()">
  <xsl:choose>
    <xsl:when test="$graphical = 'yes'">
      <xsl:text>5</xsl:text>
    </xsl:when>
    <xsl:otherwise>
      <xsl:text>3</xsl:text>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template match="/y:profile/y:services-manager/y:default_target/text()">
  <xsl:choose>
    <xsl:when test="$graphical = 'yes'">
      <xsl:text>graphical</xsl:text>
    </xsl:when>
    <xsl:otherwise>
      <xsl:text>multi-user</xsl:text>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template match="/y:profile/y:services-manager/y:services/y:enable">
  <xsl:copy>
    <xsl:apply-templates select="@*|node()" />
    <xsl:if test="$fips='yes'">
      <xsl:element name="service">
        <xsl:text>haveged</xsl:text>
      </xsl:element>
    </xsl:if>
    <xsl:if test="$graphical='yes'">
      <xsl:element name="service">
        <xsl:text>display-manager</xsl:text>
      </xsl:element>
    </xsl:if>
  </xsl:copy>
</xsl:template>

<xsl:template match="/y:profile/y:software/y:patterns">
  <xsl:copy>
    <xsl:apply-templates select="@*|node()" />
    <xsl:if test="$fips='yes'">
      <xsl:element name="pattern">
        <xsl:text>fips</xsl:text>
      </xsl:element>
      <xsl:element name="pattern">
        <xsl:text>sles-fips</xsl:text>
      </xsl:element>
    </xsl:if>
    <xsl:if test="$graphical = 'yes'">
      <xsl:element name="pattern">
        <xsl:text>gnome-basic</xsl:text>
      </xsl:element>
      <xsl:element name="pattern">
        <xsl:text>x11</xsl:text>
      </xsl:element>
    </xsl:if>
  </xsl:copy>
</xsl:template>

<xsl:template match="/y:profile/y:software/y:do_online_update">
  <xsl:element name="do_online_update">
    <xsl:attribute name="config:type"> <xsl:text>boolean</xsl:text> </xsl:attribute>
    <xsl:choose>
      <xsl:when test="$updaterepo and not(contains($updaterepo, 'SLE-SERVER/11'))">
        <xsl:text>true</xsl:text>
      </xsl:when>
      <xsl:otherwise>
        <xsl:text>false</xsl:text>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:element>
</xsl:template>

<xsl:template match="/y:profile/y:users">
  <xsl:copy>
    <xsl:apply-templates select="@*|node()" />
    <xsl:if test="$graphical='yes'">
      <xsl:element name="user">
        <xsl:element name="encrypted">
          <xsl:attribute name="config:type"> <xsl:text>boolean</xsl:text> </xsl:attribute>
          <xsl:text>true</xsl:text>
        </xsl:element>
        <xsl:element name="fullname"> <xsl:text>Gnome Display Manager daemon</xsl:text> </xsl:element>
        <xsl:element name="gid"> <xsl:text>484</xsl:text> </xsl:element>
        <xsl:element name="home"> <xsl:text>/var/lib/gdb</xsl:text> </xsl:element>
        <xsl:element name="password_settings">
          <xsl:element name="expire" /> <xsl:element name="flag" /> <xsl:element name="inact" />
          <xsl:element name="max" /> <xsl:element name="min" /> <xsl:element name="warn" />
        </xsl:element>
        <xsl:element name="shell"> <xsl:text>/bin/false</xsl:text> </xsl:element>
        <xsl:element name="uid"> <xsl:text>486</xsl:text> </xsl:element>
        <xsl:element name="user_password"> <xsl:text>!</xsl:text> </xsl:element>
        <xsl:element name="username"> <xsl:text>gdm</xsl:text> </xsl:element>
      </xsl:element>
    </xsl:if>
  </xsl:copy>
</xsl:template>

<!-- we use the following initialization script only with SLE11
     the other versions use <add_on_products>
     we can't do that with SLE11, as it does not accept rpm-md repositories
-->
<xsl:template match="/y:profile/y:scripts/y:init-scripts/y:script[y:filename = 'updates.sh']/y:source">
  <xsl:element name="source">
    <xsl:choose>
      <xsl:when test="$updaterepo and contains($updaterepo, 'SLE-SERVER/11')">
        <xsl:text>#! /bin/sh&#x0A;</xsl:text>
        <xsl:text>&#x0A;</xsl:text>
        <xsl:text>sleep 10&#x0A;</xsl:text> <!-- enough time for the other installations to finish -->
        <xsl:text>/usr/bin/zypper lr | /usr/bin/grep -q "SUSE:Updates:SLE-SERVER:11"&#x0A;</xsl:text>
        <xsl:text>if [ $? -eq 0 ]; then&#x0A;</xsl:text>
        <xsl:text>  echo "Updates repository is already added"&#x0A;</xsl:text>
        <xsl:text>else&#x0A;</xsl:text>
        <xsl:text>  /usr/bin/zypper addrepo "</xsl:text> <xsl:value-of select="$updaterepo" /> <xsl:text>" || exit 1&#x0A;</xsl:text>
        <xsl:text>fi&#x0A;</xsl:text>
        <xsl:text>/usr/bin/zypper --non-interactive --gpg-auto-import-keys refresh || exit 1&#x0A;</xsl:text>
        <xsl:text>/usr/bin/zypper --non-interactive update || exit 1&#x0A;</xsl:text>
      </xsl:when>
      <xsl:otherwise>
        <xsl:text>#! /bin/sh&#x0A;</xsl:text>
        <xsl:text>&#x0A;</xsl:text>
        <xsl:text>echo "Applying updates not requested."&#x0A;</xsl:text>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:element>
</xsl:template>

<!-- HACK - TO BE REMOVED WHEN IMPLEMENTED IN LIBRAIRIES - ASK MARCUS MEISSNER -->
<xsl:template match="/y:profile/y:files">
  <xsl:copy>
    <xsl:apply-templates select="@*|node()"/>
    <xsl:if test="$fips='yes'">
      <xsl:element name="file">
        <xsl:element name="file_path">
          <xsl:text>/etc/system-fips</xsl:text>
        </xsl:element>
        <xsl:element name="file_owner">
          <xsl:text>root:root</xsl:text>
        </xsl:element>
        <xsl:element name="file_permissions">
          <xsl:text>644</xsl:text>
        </xsl:element>
        <xsl:element name="file_contents">
          <xsl:text>&#xA;</xsl:text>  <!-- just a "touch" -->
        </xsl:element>
      </xsl:element>
    </xsl:if>
  </xsl:copy>
</xsl:template>

<xsl:template match="/y:profile/y:files/y:file[y:file_path =
  '/root/.ssh/authorized_keys']/y:file_contents/text()">
  <xsl:value-of select="unparsed-text('../files/id_rsa.pub')" />
</xsl:template>

<xsl:template match="/y:profile/y:files/y:file[y:file_path =
  '/home/testuser/.ssh/authorized_keys']/y:file_contents/text()">
  <xsl:value-of select="unparsed-text('../files/id_rsa.pub')" />
</xsl:template>

<xsl:template match="/y:profile/y:files/y:file[y:file_path =
  '/etc/zypp/repos.d/online.repo']/y:file_contents/text()">
  <xsl:value-of select="unparsed-text(concat('../files/', $onlinerepo))" />
</xsl:template>

<xsl:template match="//*[@ifarch != '']">
  <xsl:if test="contains(@ifarch, $arch)">
    <xsl:element name="{name()}">
      <xsl:apply-templates select="@*[name() != 'ifarch']|node()" />
    </xsl:element>
  </xsl:if>
</xsl:template>

<xsl:template match="@*|node()">
  <xsl:copy>
    <xsl:apply-templates select="@*|node()"/>
  </xsl:copy>
</xsl:template>

</xsl:stylesheet>
