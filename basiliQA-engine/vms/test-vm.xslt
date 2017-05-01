<?xml version="1.0"?>
<!--
  test-vm.xslt
  Style sheet to adjust a virtual machine description

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

<!-- mandatory parameters -->
<xsl:param name="name"      select="'UNDEFINED'" />
<xsl:param name="arch"      select="'UNDEFINED'" />
<xsl:param name="emulation" select="'UNDEFINED'" />
<xsl:param name="skylake"   select="'UNDEFINED'" />
<xsl:param name="memsize"   select="'UNDEFINED'" />
<xsl:param name="vcpus"     select="'UNDEFINED'" />
<xsl:param name="disk"      select="'UNDEFINED'" />

<!-- optional parameters -->
<xsl:param name="shared"   />
<xsl:param name="address0" /> <xsl:param name="network0" />
<xsl:param name="address1" /> <xsl:param name="network1" />
<xsl:param name="address2" /> <xsl:param name="network2" />
<xsl:param name="address3" /> <xsl:param name="network3" />
<xsl:param name="address4" /> <xsl:param name="network4" />
<xsl:param name="address5" /> <xsl:param name="network5" />
<xsl:param name="address6" /> <xsl:param name="network6" />
<xsl:param name="address7" /> <xsl:param name="network7" />
<xsl:param name="file0" /> <xsl:param name="dev0" />
<xsl:param name="file1" /> <xsl:param name="dev1" />
<xsl:param name="file2" /> <xsl:param name="dev2" />
<xsl:param name="file3" /> <xsl:param name="dev3" />
<xsl:param name="file4" /> <xsl:param name="dev4" />
<xsl:param name="file5" /> <xsl:param name="dev5" />
<xsl:param name="file6" /> <xsl:param name="dev6" />
<xsl:param name="file7" /> <xsl:param name="dev7" />
<xsl:param name="socket" />

<xsl:template match="/domain/@type">
  <xsl:attribute name="type">
    <xsl:choose>
      <xsl:when test="$emulation = 'no'">
        <xsl:text>kvm</xsl:text>
      </xsl:when>
      <xsl:otherwise>
        <xsl:text>qemu</xsl:text>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:attribute>
</xsl:template>

<xsl:template match="/domain/name">
  <xsl:element name="name">
    <xsl:value-of select="$name" />
  </xsl:element>
</xsl:template>

<xsl:template match="/domain/memory">
  <xsl:element name="memory">
    <xsl:attribute name="unit">B</xsl:attribute>
    <xsl:value-of select='format-number($memsize * 1024 * 1024, "0")' />
  </xsl:element>
</xsl:template>

<xsl:template match="/domain/currentMemory">
  <xsl:element name="currentMemory">
    <xsl:attribute name="unit">B</xsl:attribute>
    <xsl:value-of select='format-number($memsize * 1024 * 1024, "0")' />
  </xsl:element>
</xsl:template>

<xsl:template match="/domain/vcpu">
  <xsl:element name="vcpu">
    <xsl:attribute name="placement">static</xsl:attribute>
    <xsl:value-of select="$vcpus" />
  </xsl:element>
</xsl:template>

<xsl:template match="/domain/devices/disk[@device = 'disk' and driver/@type = 'qcow2']/source/@file">
  <xsl:attribute name="file">
    <xsl:value-of select="$disk" />
  </xsl:attribute>
</xsl:template>

<xsl:template match="/domain/devices/filesystem">
  <xsl:if test="$shared">
    <xsl:element name="filesystem">
      <xsl:attribute name='type'>mount</xsl:attribute>
      <xsl:attribute name='accessmode'>passthrough</xsl:attribute>
      <xsl:element name='source'>
        <xsl:attribute name="dir">
          <xsl:value-of select="$shared" />
        </xsl:attribute>
      </xsl:element>
      <xsl:element name='target'>
        <xsl:attribute name='dir'>RPMs</xsl:attribute>
      </xsl:element>
      <xsl:element name='address'>
        <xsl:attribute name='type'>pci</xsl:attribute>
        <xsl:attribute name='domain'>0x0000</xsl:attribute>
        <xsl:attribute name='bus'>0x00</xsl:attribute>
        <xsl:attribute name='slot'>0x18</xsl:attribute>
        <xsl:attribute name='function'>0x0</xsl:attribute>
      </xsl:element>
    </xsl:element>
  </xsl:if>
</xsl:template>

<xsl:template name="nic">
  <xsl:param name="addr" />
  <xsl:param name="net" />
  <xsl:param name="slot" />
  <xsl:if test="$addr and $net">
    <xsl:element name="interface">
      <xsl:attribute name="type">
        <xsl:text>network</xsl:text>
      </xsl:attribute>
      <xsl:element name="mac">
        <xsl:attribute name="address">
          <xsl:value-of select="$addr" />
        </xsl:attribute>
      </xsl:element>
      <xsl:element name="source">
        <xsl:attribute name="network">
          <xsl:value-of select="$net" />
        </xsl:attribute>
      </xsl:element>
      <xsl:element name="model">
        <xsl:attribute name="type">
          <xsl:text>virtio</xsl:text>
        </xsl:attribute>
      </xsl:element>
      <xsl:choose>
        <xsl:when test="$arch = 's390x'">
          <xsl:element name="address">
            <xsl:attribute name="type">
              <xsl:text>ccw</xsl:text>
            </xsl:attribute>
            <xsl:attribute name="cssid">
              <xsl:text>0xfe</xsl:text>
            </xsl:attribute>
            <xsl:attribute name="ssid">
              <xsl:text>0x0</xsl:text>
            </xsl:attribute>
            <xsl:attribute name="devno">
              <xsl:value-of select="$slot" />
            </xsl:attribute>
          </xsl:element>
        </xsl:when>
        <xsl:otherwise>
          <xsl:element name="address">
            <xsl:attribute name="type">
              <xsl:text>pci</xsl:text>
            </xsl:attribute>
            <xsl:attribute name="domain">
              <xsl:text>0x0000</xsl:text>
            </xsl:attribute>
            <xsl:attribute name="bus">
              <xsl:text>0x00</xsl:text>
            </xsl:attribute>
            <xsl:attribute name="slot">
              <xsl:value-of select="$slot" />
            </xsl:attribute>
            <xsl:attribute name="function">
              <xsl:text>0x0</xsl:text>
            </xsl:attribute>
          </xsl:element>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:element>
  </xsl:if>
</xsl:template>

<xsl:template name="disk">
  <xsl:param name="file" />
  <xsl:param name="dev" />
  <xsl:param name="slot" />
  <xsl:if test="$file and $dev">
    <xsl:element name="disk">
      <xsl:attribute name="type">
        <xsl:text>file</xsl:text>
      </xsl:attribute>
      <xsl:attribute name="device">
        <xsl:text>disk</xsl:text>
      </xsl:attribute>
      <xsl:element name="driver">
        <xsl:attribute name="name">
          <xsl:text>qemu</xsl:text>
        </xsl:attribute>
        <xsl:attribute name="type">
          <xsl:text>qcow2</xsl:text>
        </xsl:attribute>
      </xsl:element>
      <xsl:element name="source">
        <xsl:attribute name="file">
          <xsl:value-of select="$file" />
        </xsl:attribute>
      </xsl:element>
      <xsl:element name="target">
        <xsl:attribute name="dev">
          <xsl:value-of select="$dev" />
        </xsl:attribute>
        <xsl:attribute name="bus">
          <xsl:text>virtio</xsl:text>
        </xsl:attribute>
      </xsl:element>
      <xsl:element name="address">
        <xsl:attribute name="type">
          <xsl:text>pci</xsl:text>
        </xsl:attribute>
        <xsl:attribute name="domain">
          <xsl:text>0x0000</xsl:text>
        </xsl:attribute>
        <xsl:attribute name="bus">
          <xsl:text>0x00</xsl:text>
        </xsl:attribute>
        <xsl:attribute name="slot">
          <xsl:value-of select="$slot" />
        </xsl:attribute>
        <xsl:attribute name="function">
          <xsl:text>0x0</xsl:text>
        </xsl:attribute>
      </xsl:element>
    </xsl:element>
  </xsl:if>
</xsl:template>

<xsl:template match="/domain/devices/interface[1]">
  <xsl:call-template name="nic">
    <xsl:with-param name="addr" select="$address0"/>
    <xsl:with-param name="net"  select="$network0"/>
    <xsl:with-param name="slot" select="'0x08'"/>
  </xsl:call-template>
</xsl:template>

<xsl:template match="/domain/devices/interface[2]">
  <xsl:call-template name="nic">
    <xsl:with-param name="addr" select="$address1"/>
    <xsl:with-param name="net"  select="$network1"/>
    <xsl:with-param name="slot" select="'0x09'"/>
  </xsl:call-template>
</xsl:template>

<xsl:template match="/domain/devices/interface[3]">
  <xsl:call-template name="nic">
    <xsl:with-param name="addr" select="$address2"/>
    <xsl:with-param name="net"  select="$network2"/>
    <xsl:with-param name="slot" select="'0x0a'"/>
  </xsl:call-template>
</xsl:template>

<xsl:template match="/domain/devices/interface[4]">
  <xsl:call-template name="nic">
    <xsl:with-param name="addr" select="$address3"/>
    <xsl:with-param name="net"  select="$network3"/>
    <xsl:with-param name="slot" select="'0x0b'"/>
  </xsl:call-template>
</xsl:template>

<xsl:template match="/domain/devices/interface[5]">
  <xsl:call-template name="nic">
    <xsl:with-param name="addr" select="$address4"/>
    <xsl:with-param name="net"  select="$network4"/>
    <xsl:with-param name="slot" select="'0x0c'"/>
  </xsl:call-template>
</xsl:template>

<xsl:template match="/domain/devices/interface[6]">
  <xsl:call-template name="nic">
    <xsl:with-param name="addr" select="$address5"/>
    <xsl:with-param name="net"  select="$network5"/>
    <xsl:with-param name="slot" select="'0x0d'"/>
  </xsl:call-template>
</xsl:template>

<xsl:template match="/domain/devices/interface[7]">
  <xsl:call-template name="nic">
    <xsl:with-param name="addr" select="$address6"/>
    <xsl:with-param name="net"  select="$network6"/>
    <xsl:with-param name="slot" select="'0x0e'"/>
  </xsl:call-template>
</xsl:template>

<xsl:template match="/domain/devices/interface[8]">
  <xsl:call-template name="nic">
    <xsl:with-param name="addr" select="$address7"/>
    <xsl:with-param name="net"  select="$network7"/>
    <xsl:with-param name="slot" select="'0x0f'"/>
  </xsl:call-template>
</xsl:template>

<xsl:template match="/domain/devices/disk[2]">
  <xsl:call-template name="disk">
    <xsl:with-param name="file" select="$file0"/>
    <xsl:with-param name="dev" select="$dev0"/>
    <xsl:with-param name="slot" select="'0x10'"/>
  </xsl:call-template>
</xsl:template>

<xsl:template match="/domain/devices/disk[3]">
  <xsl:call-template name="disk">
    <xsl:with-param name="file" select="$file1"/>
    <xsl:with-param name="dev" select="$dev1"/>
    <xsl:with-param name="slot" select="'0x11'"/>
  </xsl:call-template>
</xsl:template>

<xsl:template match="/domain/devices/disk[4]">
  <xsl:call-template name="disk">
    <xsl:with-param name="file" select="$file2"/>
    <xsl:with-param name="dev" select="$dev2"/>
    <xsl:with-param name="slot" select="'0x12'"/>
  </xsl:call-template>
</xsl:template>

<xsl:template match="/domain/devices/disk[5]">
  <xsl:call-template name="disk">
    <xsl:with-param name="file" select="$file3"/>
    <xsl:with-param name="dev" select="$dev3"/>
    <xsl:with-param name="slot" select="'0x13'"/>
  </xsl:call-template>
</xsl:template>

<xsl:template match="/domain/devices/disk[6]">
  <xsl:call-template name="disk">
    <xsl:with-param name="file" select="$file4"/>
    <xsl:with-param name="dev" select="$dev4"/>
    <xsl:with-param name="slot" select="'0x14'"/>
  </xsl:call-template>
</xsl:template>

<xsl:template match="/domain/devices/disk[7]">
  <xsl:call-template name="disk">
    <xsl:with-param name="file" select="$file5"/>
    <xsl:with-param name="dev" select="$dev5"/>
    <xsl:with-param name="slot" select="'0x15'"/>
  </xsl:call-template>
</xsl:template>

<xsl:template match="/domain/devices/disk[8]">
  <xsl:call-template name="disk">
    <xsl:with-param name="file" select="$file6"/>
    <xsl:with-param name="dev" select="$dev6"/>
    <xsl:with-param name="slot" select="'0x16'"/>
  </xsl:call-template>
</xsl:template>

<xsl:template match="/domain/devices/disk[9]">
  <xsl:call-template name="disk">
    <xsl:with-param name="file" select="$file7"/>
    <xsl:with-param name="dev" select="$dev7"/>
    <xsl:with-param name="slot" select="'0x17'"/>
  </xsl:call-template>
</xsl:template>

<xsl:template match="/domain/devices/channel">
  <xsl:if test="$socket">
    <xsl:element name="channel">
      <xsl:attribute name="type">
        <xsl:text>unix</xsl:text>
      </xsl:attribute>
      <xsl:element name="source">
        <xsl:attribute name="mode">
          <xsl:text>bind</xsl:text>
        </xsl:attribute>
        <xsl:attribute name="path">
          <xsl:value-of select="$socket" />
        </xsl:attribute>
      </xsl:element>
      <xsl:element name="target">
        <xsl:attribute name="type">
          <xsl:text>virtio</xsl:text>
        </xsl:attribute>
        <xsl:attribute name="name">
          <xsl:text>org.opensuse.twopence.0</xsl:text>
        </xsl:attribute>
      </xsl:element>
      <xsl:element name="alias">
        <xsl:attribute name="name">
          <xsl:text>channel0</xsl:text>
        </xsl:attribute>
      </xsl:element>
      <xsl:element name="address">
        <xsl:attribute name="type">
          <xsl:text>virtio-serial</xsl:text>
        </xsl:attribute>
        <xsl:attribute name="controller">
          <xsl:text>0</xsl:text>
        </xsl:attribute>
        <xsl:attribute name="bus">
          <xsl:text>0</xsl:text>
        </xsl:attribute>
        <xsl:attribute name="port">
          <xsl:text>1</xsl:text>
        </xsl:attribute>
      </xsl:element>
    </xsl:element>
  </xsl:if>
</xsl:template>

<xsl:template name="copy-element">
  <xsl:element name="{name()}">
    <xsl:apply-templates select="@*[name() != 'ifarch' and name() != 'ifemu']|node()" />
  </xsl:element>
</xsl:template>

<!-- skylake processor treated as exception -->
<xsl:template match="//cpu[@ifarch = 'x86_64' and @ifemu = 'no']">
  <xsl:if test="$arch = 'x86_64' and $emulation = 'no'">
    <xsl:choose>
      <xsl:when test="$skylake = 'yes'">
        <xsl:element name="cpu">
          <xsl:attribute name="mode">custom</xsl:attribute>
          <xsl:attribute name="match">exact</xsl:attribute>
          <xsl:element name="model">
            <xsl:attribute name="fallback">allow</xsl:attribute>
            <xsl:text>Skylake-Client</xsl:text>
          </xsl:element>
        </xsl:element>
      </xsl:when>
      <xsl:otherwise>
        <xsl:call-template name="copy-element" />
      </xsl:otherwise>
    </xsl:choose>
  </xsl:if>
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
