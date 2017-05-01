<?xml version="1.0"?>
<!--
  basebox.xslt
  basiliQA images importer
  Style sheet to adjust virtual machine description

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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                version="1.0">

<xsl:param name="arch" select="'UNDEFINED'" />
<xsl:param name="emulation" select="'UNDEFINED'" />
<xsl:param name="disk" select="'UNDEFINED'" />
<xsl:param name="floppy" select="'UNDEFINED'" />
<xsl:param name="cdrom" select="'UNDEFINED'" />
<xsl:param name="nvram" select="'UNDEFINED'" />
<xsl:param name="kernel" select="'UNDEFINED'" />
<xsl:param name="initrd" select="'UNDEFINED'" />

<xsl:template match="/domain/@type">
  <xsl:attribute name="type">
    <xsl:choose>
      <xsl:when test="$arch != 'x86_64' and $arch != 'i586'">
        <xsl:text>qemu</xsl:text>
      </xsl:when>
      <xsl:otherwise>
        <xsl:text>kvm</xsl:text>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:attribute>
</xsl:template>

<xsl:template match="/domain/os/nvram/text()">
  <xsl:value-of select="$nvram" />
</xsl:template>

<xsl:template match="/domain/os/kernel/text()">
  <xsl:value-of select="$kernel" />
</xsl:template>

<xsl:template match="/domain/os/initrd/text()">
  <xsl:value-of select="$initrd" />
</xsl:template>

<xsl:template match="/domain/devices/disk[@device = 'cdrom']/source/@file">
  <xsl:attribute name="file">
    <xsl:value-of select="$cdrom" />
  </xsl:attribute>
</xsl:template>

<xsl:template match="/domain/devices/disk[@device = 'disk' and driver/@type = 'qcow2']/source/@file">
  <xsl:attribute name="file">
    <xsl:value-of select="$disk" />
  </xsl:attribute>
</xsl:template>

<xsl:template match="/domain/devices/disk[@device = 'disk' and driver/@type = 'raw']/source/@file">
  <xsl:attribute name="file">
    <xsl:value-of select="$floppy" />
  </xsl:attribute>
</xsl:template>

<xsl:template name="copy-element">
  <xsl:element name="{name()}">
    <xsl:apply-templates select="@*[name() != 'ifarch' and name() != 'ifemu']|node()" />
  </xsl:element>
</xsl:template>

<xsl:template match="//*[@ifarch != '']">
  <xsl:if test="contains(@ifarch, $arch)">
    <xsl:choose>
      <xsl:when test="@ifemu != ''">
        <xsl:if test="@ifemu = $emulation">
          <xsl:call-template name="copy-element" />
        </xsl:if>
      </xsl:when>
      <xsl:otherwise>
        <xsl:call-template name="copy-element" />
      </xsl:otherwise>
    </xsl:choose>
  </xsl:if>
</xsl:template>

<xsl:template match="//*[@ifemu != '']">
  <xsl:if test="@ifemu = $emulation">
    <xsl:choose>
      <xsl:when test="@ifarch != ''">
        <xsl:if test="contains(@ifarch, $arch)">
          <xsl:call-template name="copy-element" />
        </xsl:if>
      </xsl:when>
      <xsl:otherwise>
        <xsl:call-template name="copy-element" />
      </xsl:otherwise>
    </xsl:choose>
  </xsl:if>
</xsl:template>

<xsl:template match="@*|node()">
  <xsl:copy>
    <xsl:apply-templates select="@*|node()"/>
  </xsl:copy>
</xsl:template>

</xsl:stylesheet>
