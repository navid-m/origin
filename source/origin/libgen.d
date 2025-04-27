module origin.libgen;

import std.net.curl;
import std.string;
import std.conv;
import std.array;
import std.algorithm;
import std.exception;
import std.format;
import std.regex;
import arsd.dom;

private static immutable string[] MIRROR_SOURCES = [
    "GET", "Cloudflare", "IPFS.io", "Infura"
];

static class LibgenSearch
{
    static SearchRequest searchRequest;

    static string[string][] searchTitle(string query)
    {
        searchRequest = new SearchRequest(query, "title");
        return searchRequest.aggregateRequestData();
    }

    static string[string][] searchAuthor(string query)
    {
        searchRequest = new SearchRequest(query, "author");
        return searchRequest.aggregateRequestData();
    }

    static string[string][] searchTitleFiltered(string query, string[string] filters, bool exactMatch = true)
    {
        searchRequest = new SearchRequest(query, "title");
        auto results = searchRequest.aggregateRequestData();
        return filterResults(results, filters, exactMatch);
    }

    static string[string][] searchAuthorFiltered(string query, string[string] filters, bool exactMatch = true)
    {
        searchRequest = new SearchRequest(query, "author");
        auto results = searchRequest.aggregateRequestData();
        return filterResults(results, filters, exactMatch);
    }

    static string[string] resolveDownloadLinks(string[string] item)
    {
        string mirror1 = item["Mirror_1"];
        auto page = cast(string) get(mirror1);
        auto document = new Document(page);

        string[string] downloadLinks;

        foreach (link; document.querySelectorAll("a"))
        {
            string linkText = link.innerText.strip();

            if (MIRROR_SOURCES.canFind(linkText))
            {
                downloadLinks[linkText] = link.getAttribute("href");
            }
        }

        return downloadLinks;
    }
}

class SearchRequest
{
    string query;
    string searchType;

    immutable string[] colNames = [
        "ID",
        "Author",
        "Title",
        "Publisher",
        "Year",
        "Pages",
        "Language",
        "Size",
        "Extension",
        "Mirror_1",
        "Mirror_2",
        "Mirror_3",
        "Mirror_4",
        "Mirror_5",
        "Edit"
    ];

    this(string query, string searchType = "title")
    {
        this.query = query;
        this.searchType = searchType;

        if (query.length < 3)
            throw new Exception("Query is too short");

    }

    void stripITagFromSoup(Document document)
    {
        foreach (iTag; document.querySelectorAll("i"))
            iTag.parentNode.removeChild(iTag);
    }

    string getSearchPage()
    {
        string queryParsed = query.replace(" ", "%20");
        string searchUrl;

        if (searchType.toLower() == "title")
            searchUrl = format("https://libgen.is/search.php?req=%s&column=title", queryParsed);
        else if (searchType.toLower() == "author")
            searchUrl = format("https://libgen.is/search.php?req=%s&column=author", queryParsed);

        return cast(string) get(searchUrl);
    }

    string[string][] aggregateRequestData()
    {
        string searchPage = getSearchPage();
        auto document = new Document(searchPage);
        stripITagFromSoup(document);
        auto tables = document.querySelectorAll("table");

        if (tables.length < 3)
            return [];

        auto informationTable = tables[2];
        auto rows = informationTable.querySelectorAll("tr");

        string[string][] outputData;
        foreach (rowIndex; 1 .. rows.length)
        {
            auto row = rows[rowIndex];
            auto cells = row.querySelectorAll("td");

            string[string] rowData;

            foreach (i, td; cells)
            {
                if (i >= colNames.length)
                    break;

                auto anchor = td.querySelector("a");
                string value;

                if (anchor && anchor.hasAttribute("title") && anchor.getAttribute("title") != "")
                {
                    value = anchor.getAttribute("href");
                }
                else
                {
                    value = td.innerText.strip();
                }

                rowData[colNames[i]] = value;
            }

            outputData ~= rowData;
        }

        return outputData;
    }
}

string[string][] filterResults(string[string][] results, string[string] filters, bool exactMatch)
{
    string[string][] filteredList;

    if (exactMatch)
    {
        foreach (result; results)
        {
            bool allFiltersMatch = true;

            foreach (field, query; filters)
            {
                if (field !in result || result[field] != query)
                {
                    allFiltersMatch = false;
                    break;
                }
            }

            if (allFiltersMatch)
            {
                filteredList ~= result;
            }
        }
    }
    else
    {
        foreach (result; results)
        {
            bool filterMatchesResult = true;

            foreach (field, query; filters)
            {
                if (field !in result || !result[field].toLower().canFind(query.toLower()))
                {
                    filterMatchesResult = false;
                    break;
                }
            }

            if (filterMatchesResult)
            {
                filteredList ~= result;
            }
        }
    }

    return filteredList;
}

unittest
{
    assert(LibgenSearch.searchTitle("bob").length > 0);
}
