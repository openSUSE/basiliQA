//////////////////////////////////////////////////////////////////
//
// Test logging facilities for basiliQA
//
// Copyright (C) 2015,2016,2017 SUSE LLC
//
// This program is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, version 2.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
//
//
// output decomposed data to junit xml
//
//////////////////////////////////////////////////////////////////
#include <QtCore/QDateTime>
#include <QtXml/QDomDocument>

class Decomposition;

class ToJunit
{
  private:
    QDomDocument output;
    QDomElement root, testsuite, testcase;
    char *line;
    enum
      { none = 0, test_suite, test_case } state;
    int suites, tests, failures, errors, skips;
    QString suiteText, caseText;
    QDateTime suiteTime, caseTime;

    QDateTime getTime(QString &time) const;
    double timeSpan(QDateTime &date1, QDateTime &date2) const;
    void recordLine(const char *line);
    void openTestsuite(const Decomposition *d);
    void openTestcase(const Decomposition *d);
    void closeTestsuite(const Decomposition *d);
    void closeTestcase(const Decomposition *d);
    void createFailure(const Decomposition *d);
    void createError(const Decomposition *d);
    void createSkipped(const Decomposition *d);
    void createOutput(const Decomposition *d);
    void directive(const char *line);

  public:
    ToJunit();
    ~ToJunit();
    void parse(FILE *fp);
    void print(FILE *fp) const;
};
