%prep
%setup -q -n @@TYPE@@-@@PROGRAM@@-%version

%build
make all

%install
make install DESTDIR=$RPM_BUILD_ROOT


%files
%defattr(-,root,root)
%doc %{testsdir}/README


%files tests-control
%defattr(-,root,root)
%dir %{testsdir}
%dir %{testsdir}/tests-control
%dir %{testsdir}/tests-control/bin
%{testsdir}/tests-control/nodes
%{testsdir}/tests-control/bin/@@RUN@@


