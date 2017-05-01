<?xml version="1.0"?>
<!--
  testenv.xslt
  Style sheet to convert test environment file into environment variables

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
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

<xsl:output method="text" />

<xsl:template match="testenv">
  <xsl:if test="@name">
    <xsl:text>export PROJECT_NAME="</xsl:text>
    <xsl:value-of select="@name" />
    <xsl:text>"&#10;</xsl:text>
  </xsl:if>

  <xsl:if test="@parameters">
    <xsl:text>export TEST_PARAMETERS="</xsl:text>
    <xsl:value-of select="@parameters" />
    <xsl:text>"&#10;</xsl:text>
  </xsl:if>

  <xsl:if test="@workspace">
    <xsl:text>export WORKSPACE="</xsl:text>
    <xsl:value-of select="@workspace" />
    <xsl:text>"&#10;</xsl:text>
  </xsl:if>

  <xsl:if test="@report">
    <xsl:text>export REPORT="</xsl:text>
    <xsl:value-of select="@report" />
    <xsl:text>"&#10;</xsl:text>
  </xsl:if>

  <xsl:text>export NETWORKS="</xsl:text>
  <xsl:for-each select="network">
    <xsl:if test="count(preceding-sibling::network) != 0">
      <xsl:text> </xsl:text>
    </xsl:if>
    <xsl:value-of select="@name" />
  </xsl:for-each>
  <xsl:text>"&#10;</xsl:text>

  <xsl:text>export NODES="</xsl:text>
  <xsl:for-each select="node">
    <xsl:if test="count(preceding-sibling::node) != 0">
      <xsl:text> </xsl:text>
    </xsl:if>
    <xsl:value-of select="@name" />
  </xsl:for-each>
  <xsl:text>"&#10;</xsl:text>

  <xsl:apply-templates />
</xsl:template>

<xsl:template match="vms">
  <xsl:if test="@virsh-uri">
    <xsl:text>export DEFAULT_VIRSH_URI="</xsl:text>
    <xsl:value-of select="@virsh-uri" />
    <xsl:text>"&#10;</xsl:text>
  </xsl:if>

  <xsl:if test="@model">
    <xsl:text>export VM_MODEL="</xsl:text>
    <xsl:value-of select="@model" />
    <xsl:text>"&#10;</xsl:text>
  </xsl:if>
</xsl:template>

<xsl:template match="network">
  <xsl:variable name="netname">
    <xsl:value-of select="translate(@name, 'abcdefghijklmnopqrstuvwxyz', 'ABCDEFGHIJKLMNOPQRSTUVWXYZ')" />
  </xsl:variable>

  <xsl:if test="@subnet">
    <xsl:text>export SUBNET_</xsl:text>
    <xsl:value-of select="$netname" />
    <xsl:text>="</xsl:text>
    <xsl:value-of select="@subnet" />
    <xsl:text>"&#10;</xsl:text>
  </xsl:if>

  <xsl:if test="@subnet6">
    <xsl:text>export SUBNET6_</xsl:text>
    <xsl:value-of select="$netname" />
    <xsl:text>="</xsl:text>
    <xsl:value-of select="@subnet6" />
    <xsl:text>"&#10;</xsl:text>
  </xsl:if>

  <xsl:if test="@gateway">
    <xsl:text>export GATEWAY_</xsl:text>
    <xsl:value-of select="$netname" />
    <xsl:text>="</xsl:text>
    <xsl:value-of select="@gateway" />
    <xsl:text>"&#10;</xsl:text>
  </xsl:if>
</xsl:template>

<xsl:template match="node">
  <xsl:variable name="nodename">
    <xsl:value-of select="translate(@name, 'abcdefghijklmnopqrstuvwxyz', 'ABCDEFGHIJKLMNOPQRSTUVWXYZ')" />
  </xsl:variable>

  <xsl:if test="@target">
    <xsl:text>export TARGET_</xsl:text>
    <xsl:value-of select="$nodename" />
    <xsl:text>="</xsl:text>
    <xsl:value-of select="@target" />
    <xsl:text>"&#10;</xsl:text>
  </xsl:if>

  <xsl:if test="@internal-ip">
    <xsl:text>export INTERNAL_IP_</xsl:text>
    <xsl:value-of select="$nodename" />
    <xsl:text>="</xsl:text>
    <xsl:value-of select="@internal-ip" />
    <xsl:text>"&#10;</xsl:text>
  </xsl:if>

  <xsl:if test="@external-ip">
    <xsl:text>export EXTERNAL_IP_</xsl:text>
    <xsl:value-of select="$nodename" />
    <xsl:text>="</xsl:text>
    <xsl:value-of select="@external-ip" />
    <xsl:text>"&#10;</xsl:text>
  </xsl:if>

  <xsl:if test="@ip6">
    <xsl:text>export IP6_</xsl:text>
    <xsl:value-of select="$nodename" />
    <xsl:text>="</xsl:text>
    <xsl:value-of select="@ip6" />
    <xsl:text>"&#10;</xsl:text>
  </xsl:if>

  <xsl:apply-templates />
</xsl:template>

<xsl:template match="interface">
  <xsl:variable name="intname">
    <xsl:value-of select="translate(../@name, 'abcdefghijklmnopqrstuvwxyz', 'ABCDEFGHIJKLMNOPQRSTUVWXYZ')" />
    <xsl:text>_</xsl:text>
    <xsl:value-of select="translate(@name, 'abcdefghijklmnopqrstuvwxyz', 'ABCDEFGHIJKLMNOPQRSTUVWXYZ')" />
  </xsl:variable>

  <xsl:if test="@internal-ip">
    <xsl:text>export INTERNAL_IP_</xsl:text>
    <xsl:value-of select="$intname" />
    <xsl:text>="</xsl:text>
    <xsl:value-of select="@internal-ip" />
    <xsl:text>"&#10;</xsl:text>
  </xsl:if>

  <xsl:if test="@external-ip">
    <xsl:text>export EXTERNAL_IP_</xsl:text>
    <xsl:value-of select="$intname" />
    <xsl:text>="</xsl:text>
    <xsl:value-of select="@external-ip" />
    <xsl:text>"&#10;</xsl:text>
  </xsl:if>

  <xsl:if test="@ip6">
    <xsl:text>export IP6_</xsl:text>
    <xsl:value-of select="$intname" />
    <xsl:text>="</xsl:text>
    <xsl:value-of select="@ip6" />
    <xsl:text>"&#10;</xsl:text>
  </xsl:if>

  <xsl:if test="@network">
    <xsl:text>export IP6_</xsl:text>
    <xsl:value-of select="$intname" />
    <xsl:text>="</xsl:text>
    <xsl:value-of select="@network" />
    <xsl:text>"&#10;</xsl:text>
  </xsl:if>
</xsl:template>

<xsl:template match="disk">
  <xsl:variable name="diskname">
    <xsl:value-of select="translate(../@name, 'abcdefghijklmnopqrstuvwxyz', 'ABCDEFGHIJKLMNOPQRSTUVWXYZ')" />
    <xsl:text>_DISK</xsl:text>
    <xsl:value-of select="count(preceding-sibling::disk)" />
  </xsl:variable>

  <xsl:text>export DISK_NAME_</xsl:text>
  <xsl:value-of select="$diskname" />
  <xsl:text>="</xsl:text>
  <xsl:value-of select="@name" />
  <xsl:text>"&#10;</xsl:text>

  <xsl:if test="@size">
    <xsl:text>export DISK_SIZE_</xsl:text>
    <xsl:value-of select="$diskname" />
    <xsl:text>="</xsl:text>
    <xsl:value-of select="@size" />
    <xsl:text>"&#10;</xsl:text>
  </xsl:if>
</xsl:template>

<xsl:template match="*|@*">
  <xsl:apply-templates />
</xsl:template>

<xsl:template match="text()" />

</xsl:stylesheet>
