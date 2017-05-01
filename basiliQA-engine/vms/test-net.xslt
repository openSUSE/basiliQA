<?xml version="1.0"?>
<!--
  test-net.xslt
  Style sheet to adjust a virtual network description

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

<xsl:param name="name" select="'UNDEFINED'" />
<xsl:param name="bridge_name" select="'UNDEFINED'" />
<xsl:param name="mac" select="'UNDEFINED'" />
<xsl:param name="address" select="'UNDEFINED'" />
<xsl:param name="prefix" select="'UNDEFINED'" />
<xsl:param name="address6" select="'UNDEFINED'" />
<xsl:param name="prefix6" select="'UNDEFINED'" />
<xsl:param name="dhcp_start" select="'UNDEFINED'" />
<xsl:param name="dhcp_end" select="'UNDEFINED'" />
<xsl:param name="gateway" select="'UNDEFINED'" />

<xsl:template match="/network/name">
  <xsl:element name="name">
    <xsl:value-of select="$name" />
  </xsl:element>
  <xsl:if test="$gateway = 'yes'">
    <xsl:element name="forward">
      <xsl:attribute name="mode">
        <xsl:text>nat</xsl:text>
      </xsl:attribute>
    </xsl:element>
  </xsl:if>
</xsl:template>

<xsl:template match="/network/bridge/@name">
  <xsl:attribute name="name">
    <xsl:value-of select="concat($bridge_name, '-br0')" />
  </xsl:attribute>
</xsl:template>

<xsl:template match="/network/mac/@address">
  <xsl:attribute name="address">
    <xsl:value-of select="$mac" />
  </xsl:attribute>
</xsl:template>

<xsl:template match="/network/ip">
  <!-- no need for IP addresses on the host when there is neither a gateway nor DHCP -->
  <xsl:if test="$gateway = 'yes' or $dhcp_start and $dhcp_end">

    <xsl:if test="$address and $prefix">
      <xsl:element name="ip">
        <xsl:attribute name="address">
          <xsl:value-of select="$address" />
        </xsl:attribute>
        <xsl:attribute name="prefix">
          <xsl:value-of select="$prefix" />
        </xsl:attribute>
        <xsl:if test="$dhcp_start and $dhcp_end">
          <xsl:element name="dhcp">
            <xsl:element name="range">
              <xsl:attribute name="start">
                <xsl:value-of select="$dhcp_start"/>
              </xsl:attribute>
              <xsl:attribute name="end">
                <xsl:value-of select="$dhcp_end"/>
              </xsl:attribute>
            </xsl:element>
          </xsl:element>
        </xsl:if>
      </xsl:element>
    </xsl:if>

    <xsl:if test="$address6 and $prefix6">
      <xsl:element name="ip">
        <xsl:attribute name="family">
          <xsl:text>ipv6</xsl:text>
        </xsl:attribute>
        <xsl:attribute name="address">
          <xsl:value-of select="$address6" />
        </xsl:attribute>
        <xsl:attribute name="prefix">
          <xsl:value-of select="$prefix6" />
        </xsl:attribute>
      </xsl:element>
    </xsl:if>

  </xsl:if>
</xsl:template>

<xsl:template match="@*|node()">
  <xsl:copy>
    <xsl:apply-templates select="@*|node()"/>
  </xsl:copy>
</xsl:template>

</xsl:stylesheet>
