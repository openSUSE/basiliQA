#
# Copyright (C) @@YEAR@@ @@PACKAGER@@ <@@EMAIL@@>
#
# All modifications and additions to the file contributed by third parties
# remain the property of their copyright owners, unless otherwise agreed
# upon. The license for this file, and modifications and additions to the
# file, is the same license as for the pristine package itself (unless the
# license for the pristine package is not an Open Source License, in which
# case the license is the MIT License). An "Open Source License" is a
# license that conforms to the Open Source Definition (Version 1.9)
# published by the Open Source Initiative.


Name:           @@TYPE@@-@@PROGRAM@@

Summary:        @@SUMMARY@@
License:        GPL-2.0
Group:          QA
Url:            http://www.suse.com
Version:        @@VERSION@@
Release:        0
Source0:        %{name}-%{version}.tgz
BuildRoot:      %{_tmppath}/%{name}-%{version}-build
BuildArch:      noarch
Packager:	@@PACKAGER@@ <@@EMAIL@@>

%define testsdir /var/lib/basiliqa/%{name}

%description
basiliQA test suite for @@PROGRAM@@. This main package is empty.


%package tests-control
Group:          QA
Summary:	Test suite control scripts installed on the Jenkins server
BuildArch:      noarch
Prereq:         basiliqa@@SUSETEST@@

%description tests-control
This is the testing software. It merely starts the tests on
the systems under tests. Each test can run under a different
user and with other different options.


