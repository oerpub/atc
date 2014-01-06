# Github-Book EPUB3 File Structure
Github-book uses an unzipped EPUB3 structure to store textbooks. Multiple textbooks can be in a single repo because a single EPUB can contain multiple books.  Note, however, that readium will reject an epub with multiple books in it, so all but one must be stripped when exporting for readers.

An EPUB3 must have a META-INF directory with a container.xml file that lists all the books (an .opf file per book). From the .opf, it is possible to find everything else about the book: its table of contents, its html contents, and its other resources like images. None of these other things have to be placed in a particular file structure, since they are listed in the opf. But github-book will create new books, modules, etc in a particular structure which we recommend for all repos. 

## Directory and File Structure
    META-INF/
        container.xml
    mimetype 
    content/
        <book-name>.opf
        <book-name>-nav.xhtml
        <module-name>.xhtml
    resources/
        <image>.<extension>

### mimetype file
File used by epub readers. Contains : : application/epub+zip

### META-INF/container.xml
Lists all books. It will also list folders, but those aren't implemented yet. Folders will be a book with a distinguishable mimetype so that it displays and behaves specially.
    <container xmlns="urn:oasis:names:tc:opendocument:xmlns:container" version="1.0">
       <rootfiles>
       <rootfile media-type="application/oebps-package+xml" full-path="content/package-physics-12.opf" version="1.0"/>
       </rootfiles>
    </container>
### OPF files (one for each book or folder (future))
Each OPF file has a package declaration, metadata about the book, a manifest that lists all files which includes the module html files, all images and other resources, and the navigation file. Each one gets an ID for reference within the spine of the opf file. Finally, the opf contains a spine that lists the modules in order. This should match the navigation file, or the next buttons, which are controlled by the spine, will not go to the expected location as shown in the Table of Contents (controlled by the nav file).

Note that resources listed in the .opf should be given paths that are relative to the location of the .opf file.

#### Ex: content/package-physics-12.opf
    <?xml version="1.0" encoding="UTF-8"?>
    <package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifer="uid">
    <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
        <dc:identifier id="uid">siyavula.com.dummy-book-repo.1.0</dc:identifier>
        <dc:title>Siyavula: Physics Gr 12</dc:title>
        <dc:creator>Siyavula Education</dc:creator>
        <dc:language>en</dc:language>
        <meta property="dcterms:modified">Mon Aug 19 19:35:43 2013 GMT</meta>
     </metadata>
     <manifest>
         <item id="84d7da79716bb7152c6d91b77b4e3faa.png" href="../resources/84d7da79716bb7152c6d91b77b4e3faa.png" media-type="image/png"/>
         <item id="BenchPress-by-ABlight-on-Flickr-4411752843_007003fbb7_o.jpg" href="../resources/BenchPress-by-ABlight-on-Flickr-4411752843_007003fbb7_o.jpg" media-type="image/jpeg"/>
         <item id="section-0" href="01-Skills-for-science.section-01.html" media-type="application/xhtml+xml"/>
         <item id="section-1" href="01-Skills-for-science.section-02.html" media-type="application/xhtml+xml"/>
         <item id="section-2" href="01-Skills-for-science.section-03.html" media-type="application/xhtml+xml"/>
         <item id="section-3" href="02-Momentum.section-04.html" media-type="application/xhtml+xml"/>
         <item id="section-4" href="02-Momentum.section-05.html" media-type="application/xhtml+xml"/>
         <item id="section-5" href="02-Momentum.section-06.html" media-type="application/xhtml+xml"/>
        <item id="nav" href="physics-12.nav.html" media-type="application/xhtml+xml" properties="nav"/>
    </manifest>
    <spine>
       <itemref idref="section-0"/>
       <itemref idref="section-1"/>
       <itemref idref="section-2"/>     
       <itemref idref="section-3"/>
       <itemref idref="section-4"/>
       <itemref idref="section-5"/>
    </spine>
    </package>

### The nav file: Table of contents
Each book has a navigation file which is an html file with links that is used for a formatted table of contents in the EPUB navigation. The order of items in the nav file should match the order in the spine in the .opf file. The nav file for new books will live in /content and be named <bookname>-nav.xhtml 

#### Ex: content/physics-12.nav.html
    <?xml version="1.0" encoding="UTF-8"?>
    <html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
       <head>undefined</head>
       <body><h1>Table of Contents</h1>
       <nav epub:type="toc">
          <ol>
           <li class="chapter">
              <span>Introduction: The Nature of Science and Physics</span>
              <ol>
                <li><a href="01-Skills-for-science.section-01.html">Scientific Theories</a></li>
                <li><a href="01-Skills-for-science.section-02.html">How Science Works</a></li>
                <li><a href="01-Skills-for-science.section-03.html">Scientific Graphs</a></li>
              </ol>
           </li>
           <li class="chapter">
             <span>Momentum and Impulse</span>
             <ol>
                <li><a href="02-Momentum.section-04.html">Momentum</a></li>
                <li><a href="02-Momentum.section-05.html">Impulse</a></li>
                <li><a href="02-Momentum.section-06.html">Exercises</a></li>
             </ol>
          </li>
       </ol>
      </nav>
    </body>
    </html>

### Modules
Each module is an xhtml file in the XHTML5 TextbookHTML format. They can live anywhere as long as they are in the EPUB3 zip and correctly referenced in the .opf file. New ones will be put in /content.

#### Resources like images
Images and other resources are files in some media format. They can live anywhere as long as they are in the EPUB zip and correctly referenced in the .opf file. New ones will be put in /resources.
