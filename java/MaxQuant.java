import java.io.*;
import java.util.StringTokenizer; 
import java.math.*;
import java.io.File;
import java.io.FileNotFoundException;
import java.util.Scanner;
import java.sql.*;
class MaxQuantGFFtoTrinitytoMYSQLlite
{
   public static void main(String args[])
  {
      try{
    // Open Files needed     
    FileInputStream fstream = new FileInputStream(args[0]);
    DataInputStream in = new DataInputStream(fstream);
    BufferedReader br = new BufferedReader(new InputStreamReader(in));
    File file = new File(args[0]); 
	Scanner scanner = new Scanner(file);
	String ToPrint = args[1]; 
	String PrintSent = "verbose";
    String strLine;
    // Set Varibles needed for Parser  
	int ArrayInitialize=0;
	int LineCounter=0;
	int LineCounter1=0;
	int LineCounter2=0;
    String BlastNameHolder = "";
	String DatabaseIndexHolder = "";
	int FoundSent = 0;
	String BlastMatchCheck = "";
	String HeapForPrint = "";
	int FoundIndex=0;
	int NotFoundIndex = 0;
	String BlastIndexCheck ="";
	String MaxQuantGFFtoTrinityIndexHolder = "";
	String UniprotMatchCheck = "";
	int ArrayInitialize2=0;
	String ParsedMascotHolder = "";
	int InCorrectCounter = 0;
	String ParsedMascotIndexCheck = "";
	int MatchFoundflag = 0;
	int MatchFoundCounter = 0;
	int NotFoundCounter = 0;
    String removecomment = "";
	String MaxQuantGFFtoTrinityquery_prot_idToken = "";
	String MaxQuantGFFtoTrinitySourceToken = "";
	String MaxQuantGFFtoTrinityFeatureToken = "";
	String MaxQuantGFFtoTrinityStartToken = "";
	String MaxQuantGFFtoTrinityEndToken = "";
	String MaxQuantGFFtoTrinityScoreryToken = "";
	String MaxQuantGFFtoTrinitydot1Token = "";
	String Signaldot2Token = "";
	String MaxQuantGFFtoTrinityredictionToken = "";
	String MaxQuantGFFtoTrinityQueryChild = "";
    String MaxQuantGFFtoTrinityParentChild = "";
    String MaxQuantGFFtoTrinityQueryStartToken = "";
    String MaxQuantGFFtoTrinityQueryEndToken = "";
    String MaxQuantGFFtoTrinityQueryIdenitiy = "";
    String MaxQuantGFFtoTrinityQueryStrandToken= "";
    String MaxQuantGFFtoTrinityUnknowntoken = "";
    String MaxQuantGFFtoTrinityTrinityTranscriptIDToken = "";
    String MaxQuantGFFtoTrinityFKPMToken1 = "";
    String MaxQuantGFFtoTrinityFKPMToken2 = "";
    String MaxQuantGFFtoTrinityProteinMatchToken= "";
	String MaxQuantExonToken = "";
	String CompValueFordatabase= "";
	String MaxQuantSeqTemp = "";
	String MaxQuantSeqMatchForDBASE = "";
	String TempFPKM = "";
	String ScoreTemp= "";
	String MaxQuantScoreForDBASE = "";
	String MaxQuantExonForDBASE = "";
	String ExonTemp= "";
	String MaxQauntFPKMforDBASE = "";
	String EqualSent = "\\=";
	String SemicolonSent = "\\;";
	String[] StringSplit;
	
	Class.forName("org.sqlite.JDBC");
	Connection conn = DriverManager.getConnection("jdbc:sqlite:Trinotate.sqlite");
	Statement stat = conn.createStatement();
       stat.executeUpdate("delete from MaxQuantGFFtoTrinity;");
	
	    while ((strLine = br.readLine()) != null)   
    {
    	ArrayInitialize++;
    }
	String MaxQuantGFF[] = new String[ArrayInitialize];


	
	while(scanner.hasNextLine())
	{
	MaxQuantGFF[LineCounter] = scanner.nextLine();
	LineCounter++;
	}

	PreparedStatement prep = conn.prepareStatement("insert into MaxQuantGFFtoTrinity values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);");
	

	
	    for (int i=0; i<LineCounter; i++)
		{
		MaxQuantGFFtoTrinityIndexHolder = MaxQuantGFF[i];
		StringTokenizer st1 = new StringTokenizer(MaxQuantGFFtoTrinityIndexHolder);
	 	 MaxQuantGFFtoTrinityQueryChild = st1.nextToken();
	     MaxQuantGFFtoTrinityParentChild = st1.nextToken();
	     MaxQuantGFFtoTrinityQueryStartToken = st1.nextToken();
	     MaxQuantGFFtoTrinityQueryEndToken = st1.nextToken();
	     MaxQuantGFFtoTrinityQueryIdenitiy = st1.nextToken();
	     MaxQuantGFFtoTrinityQueryStrandToken= st1.nextToken();
	     MaxQuantGFFtoTrinityUnknowntoken = st1.nextToken();
		 MaxQuantGFFtoTrinityTrinityTranscriptIDToken = st1.nextToken();
		 StringSplit = MaxQuantGFFtoTrinityTrinityTranscriptIDToken.split(EqualSent);
		  CompValueFordatabase =StringSplit[1];
		 MaxQuantGFFtoTrinityFKPMToken1 = st1.nextToken();
		 StringSplit = MaxQuantGFFtoTrinityFKPMToken1.split(SemicolonSent);
		 TempFPKM =StringSplit[0];
		 StringSplit = TempFPKM.split(EqualSent);
		 MaxQauntFPKMforDBASE=StringSplit[1];
		 MaxQuantGFFtoTrinityFKPMToken2 = st1.nextToken();
		 MaxQuantGFFtoTrinityProteinMatchToken = st1.nextToken();
		 StringSplit = MaxQuantGFFtoTrinityProteinMatchToken.split(SemicolonSent);
		 MaxQuantSeqTemp = StringSplit[1];
		 ScoreTemp = StringSplit[2];
		 ExonTemp = StringSplit[7];
		 StringSplit = MaxQuantSeqTemp.split(EqualSent);
		 MaxQuantSeqMatchForDBASE=StringSplit[1];
		 StringSplit = ScoreTemp.split(EqualSent);
		 MaxQuantScoreForDBASE=StringSplit[1];
		 StringSplit = ExonTemp.split(EqualSent);
		 MaxQuantExonForDBASE=StringSplit[1];
		 

            prep.setString(1,MaxQuantGFFtoTrinityQueryChild);
			prep.setString(2,MaxQuantGFFtoTrinityParentChild);
			prep.setString(3,MaxQuantGFFtoTrinityQueryStartToken);
			prep.setString(4,MaxQuantGFFtoTrinityQueryEndToken);
			prep.setString(5,MaxQuantGFFtoTrinityQueryStrandToken);
			prep.setString(6,CompValueFordatabase);
			prep.setString(7,MaxQauntFPKMforDBASE);
			prep.setString(8,MaxQuantSeqMatchForDBASE);
			prep.setString(9,MaxQuantScoreForDBASE);
			prep.setString(10,MaxQuantExonForDBASE);
		    prep.addBatch();	
	
		}
		
	conn.setAutoCommit(false);
    prep.executeBatch();
	conn.setAutoCommit(true);
	if (ToPrint.equals(PrintSent))
	{
	ResultSet rs = stat.executeQuery("select * from MaxQuantGFFtoTrinity;");
    while (rs.next()) {
      System.out.println("MaxQuantQueryValue = " + rs.getString("MaxQuantQueryID"));
      System.out.println("MaxQuantParentValue = " + rs.getString("MaxQuantQueryParentID"));
	  System.out.println("MaxQuantAlignmentTrinityStart = " + rs.getString("MaxQuantProteinMatchStart"));
      System.out.println("MaxQuantAlignmentTrinityEnd = " + rs.getString("MaxQuantProteinMatchend"));
	  System.out.println("MaxQauntStrandValue = " + rs.getString("MaxQuantStrand"));  
	  System.out.println("MaxQauntTrinityCompID = " + rs.getString("MaxQuantTrinityMatchID"));
      System.out.println("MaxQuantCompFPKMValue = " + rs.getString("MaxQuantscoreFKPMValue"));
	  System.out.println("MaxQuantProteinMassSpecSequenceMatch = " + rs.getString("MaxQuantPeptideValue"));
      System.out.println("MaxQuantProteinSequenceScore = " + rs.getString("MaxQuantPeptideScore"));
	  System.out.println("MaxQuantTrinityTranscriptExon = " + rs.getString("MaxQuantExonValue"));  
   }	
   }
		
		

   
   //Close the input stream
     in.close();
	 conn.close();
	

	
	
	 
    }catch (Exception e){//Catch exception if any
      System.err.println("Error: " + e.getMessage());
      e.printStackTrace();
      System.exit(1);


    }
  }
  }

