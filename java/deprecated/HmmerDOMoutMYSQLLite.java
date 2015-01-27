import java.io.*;
import java.util.StringTokenizer; 
import java.math.*;
import java.io.File;
import java.io.FileNotFoundException;
import java.util.Scanner;
import java.sql.*;

class HmmerDOMoutMYSQLLite {

    public static void main(String args[]) {

        String usage = " java HmmerDOMoutMYSQLLite pfam.hmmer.out (verbose|counter) ";
        if (args.length < 2) {
            System.err.println(usage);
            System.exit(1);
        }
        
        try{
            // Open Files needed     
            FileInputStream fstream = new FileInputStream(args[0]);
            DataInputStream in = new DataInputStream(fstream);
            BufferedReader br = new BufferedReader(new InputStreamReader(in));
            File file = new File(args[0]); 
            Scanner scanner = new Scanner(file);
            String strLine;
            String ToPrint = args[1]; 
            String PrintSent = "verbose";
            // Set Varibles needed for Parser  
            int ArrayInitialize=0;
            int LineCounter=0;
            String ProgressCounterSENT = "counter";
            String HMMERTokenHolder;
            String HMMERTokenHolder2;    
            String HMMERTargetNameToken;
            String pfam_idToken;
            String HMMERtlentoken;
            String HMMERQueryProtIDToken;
            String HMMERqlentoken;
            String HMMERFullSeqEvalue;
            String HMMERFullSeqscoretoken;
            String HMMERFullSeqbiastoken;
            String HMMERThisDomainPoundToken;
            String HMMERThisDomainofToken;
            String HMMERThisDomaincEvalueToken;
            String HMMERThisDomainiEvaluetoken;
            String HMMERThisDomainscoreToken;
            String HMMERThisbiasToken;
            String HMMERhmmcoordfromToken;
            String HMMERhmmcoordtoToken;
            String HMMERalicoordfromToken;
            String HMMERalicordtoToken;
            String HMMERenvcordfromToken;
            String HMMERenvcordtoToken;
            String HMMERaccToken;
            String HMMERTargetDescriptiontoken="";
            String HMMERTargetNameToken2;
            String pfam_idToken2;
            String HMMERtlentoken2;
            String HMMERQueryProtIDToken2;
            String HMMERqlentoken2;
            String HMMERFullSeqEvalue2;
            String HMMERFullSeqscoretoken2;
            String HMMERFullSeqbiastoken2;
            String HMMERThisDomainPoundToken2;
            String HMMERThisDomainofToken2;
            String HMMERThisDomaincEvalueToken2;
            String HMMERThisDomainiEvaluetoken2;
            String HMMERThisDomainscoreToken2;
            String HMMERThisbiasToken2;
            String HMMERhmmcoordfromToken2;
            String HMMERhmmcoordtoToken2;
            String HMMERalicoordfromToken2;
            String HMMERalicordtoToken2;
            String HMMERenvcordfromToken2;
            String HMMERenvcordtoToken2;
            String HMMERaccToken2;
            String HMMERTargetDescriptiontoken2 = "";
            String DomainEnvolope1= "";
            String DomainEnvolope2= "";
            String HMMERDescriptionTokens2="";	
            String ModelHeap ="";
            // Set Variables need to count and place in proper stratas 
            String Spacer = "            ";
            String TempTokenHolder ="";
            int NoiseCutOFFArrayInitialize =0;
            int NoiseCutOFFArrayIndex =0;
            String ThisDomainNoiseValue = "";
            String ThisSequneceNoiseValue = "";
            String ThisDomainGatheredValue = "";
            String ThisSequneceGatheredValue = "";
            String ThisDomainTrustedValue = "";
            String ThisSequneceTrustedValue = "";
            String NoiseTempHolder = "";
            String GASeqHolder = "";
            String GADOMHolder = "";
            String NoisePerSeqHolder = "";
            String NoisePerDommainHolder = "";
            String TrustedPerSeqHolder = "";
            String TrustedPerDomHolder = "";
            String NoiseAccesionHolder = "";
            String pfam_idToken2forCheck = "";
            String pfam_idTokenForCheck1 = "";
            String HMMERFullSeqScore1token = "";
            int NumberofDomainsFound = 1;
            int DebugCounter = 0;
            Class.forName("org.sqlite.JDBC");
            
            //sqllitedatabase
            Connection conn = DriverManager.getConnection("jdbc:sqlite:Trinotate.sqlite");
            Statement stat = conn.createStatement();
            stat.executeUpdate("delete from HMMERDbase;");
            
            
            // read in files to arrays
            
            while ((strLine = br.readLine()) != null)   
                {
                    ArrayInitialize++;
                }
            int withsent=ArrayInitialize+2;
            String TotalFile[] = new String[withsent];
            String NoiseCutoffArray[] =new String[NoiseCutOFFArrayInitialize];
            int ArrayInitialize2 = ArrayInitialize * 2;
            String CompletedModels[] = new String[ArrayInitialize2];
            String removecomment;
            String ARRAYSENT="SENT";
            
            while(scanner.hasNextLine())
                {
                    String line = scanner.nextLine();
                    if (line.charAt(0) == '#') {
                        // ignore comment lines
                        continue;
                    }
                    TotalFile[LineCounter] = line;
                    LineCounter++;
                }
            
            
            
            int SentValue = LineCounter +1;
            TotalFile[SentValue]=ARRAYSENT;
            int senttest = SentValue-1;	
            int NumberofEntries=0;
            TotalFile[LineCounter]=ARRAYSENT;
            NumberofEntries=ArrayInitialize-3;
            int HeapArrayCounter = 0;
            
            
            strLine = TotalFile[0];
            HMMERTokenHolder=(strLine);
            StringTokenizer st = new StringTokenizer(HMMERTokenHolder);
            HMMERTargetNameToken=st.nextToken();
            pfam_idTokenForCheck1=st.nextToken();
            HMMERtlentoken=st.nextToken();
            HMMERQueryProtIDToken=st.nextToken();
            pfam_idToken=st.nextToken();
            HMMERqlentoken=st.nextToken();
            HMMERFullSeqEvalue=st.nextToken();
            HMMERFullSeqScore1token=st.nextToken();
            HMMERFullSeqbiastoken=st.nextToken();
            HMMERThisDomainPoundToken=st.nextToken();
            HMMERThisDomainofToken=st.nextToken();
            HMMERThisDomaincEvalueToken=st.nextToken();
            HMMERThisDomainiEvaluetoken=st.nextToken();
            HMMERThisDomainscoreToken=st.nextToken();
            
            
            
            
            
            Double HMMERFullSeqScore1  = new Double(HMMERFullSeqScore1token);
            
            Double HMMERThisDomainSeqScore1  = new Double(HMMERThisDomainscoreToken);
            
	
            

            HMMERThisbiasToken=st.nextToken();
            HMMERhmmcoordfromToken=st.nextToken();
            HMMERhmmcoordtoToken=st.nextToken();
            HMMERalicoordfromToken=st.nextToken();
            HMMERalicordtoToken=st.nextToken();
            HMMERenvcordfromToken=st.nextToken();
            HMMERenvcordtoToken=st.nextToken();
            HMMERaccToken=st.nextToken();
            
            
            
            
            while (st.hasMoreTokens())
                {
                    TempTokenHolder=st.nextToken();
                    HMMERTargetDescriptiontoken=HMMERTargetDescriptiontoken+" "+TempTokenHolder;
                }
            DomainEnvolope1= HMMERenvcordfromToken + ":" + HMMERenvcordtoToken;
            ModelHeap= ModelHeap + "  " + HMMERTargetNameToken + "  " + HMMERTargetDescriptiontoken + "<DomainEnvolope:" + DomainEnvolope1 + ">" + "<FullSeqeunce Evalue:" + HMMERFullSeqEvalue +">" + "<This Domain Evalue:" +  HMMERThisDomainiEvaluetoken +">" +"<PerSequnece Score:"  + HMMERFullSeqScore1token + "|PerDomain Score:" + HMMERThisDomainscoreToken + ">" + "<HMMER Database Values GASeq|GADom|NCSeq|NCDom|TCSeq|TCDom>" + "<" + GASeqHolder +"|" + GADOMHolder +"|" + NoisePerSeqHolder + "|" + NoisePerDommainHolder + "|" + TrustedPerSeqHolder + "|" + TrustedPerDomHolder  + ">" + "<ValuesMet (YES/NO)= GASeq|GADom|NCSeq|NCDom|TCSeq|TCDOm>" +"<" + ThisSequneceGatheredValue+"|" + ThisDomainGatheredValue +"|" + ThisSequneceNoiseValue+ "|" + ThisDomainNoiseValue+ "|" + ThisSequneceTrustedValue+ "|" + ThisDomainTrustedValue + ">" + "|||||||";
            
            
            PreparedStatement prep = conn.prepareStatement("insert into HMMERDbase values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);");
            prep.setString(1,HMMERQueryProtIDToken);
            prep.setString(2,pfam_idTokenForCheck1);
            prep.setString(3,HMMERTargetNameToken);
            prep.setString(4,HMMERTargetDescriptiontoken);
            prep.setString(5,HMMERalicoordfromToken);
            prep.setString(6,HMMERalicordtoToken);
            prep.setString(7,HMMERhmmcoordfromToken);
            prep.setString(8,HMMERhmmcoordtoToken);
            prep.setString(9,HMMERFullSeqEvalue);
            prep.setString(10,HMMERThisDomainiEvaluetoken);
            prep.setString(11,HMMERFullSeqScore1token);
            prep.setString(12,HMMERThisDomainscoreToken);
            prep.addBatch();
            
            // for loop, cylces through file array, tokenizes compares, commits 
            for (int i=1; i<=LineCounter; i++)
                {
                 				
				
				
                    if (ToPrint.equals(ProgressCounterSENT))
                        {
                            if (i%1000 == 0)
                                {
                                    System.out.print("\rProcessed Entry:" + i + "   ");
                                }
                        }
                    strLine= TotalFile[i];
					  if (strLine.startsWith("#")) 
					  {
                    continue;
                       }
					
					
					
                    boolean check = strLine.equals(ARRAYSENT);	
                    if (!check)
                        {
                            strLine= TotalFile[i];
                            HMMERTokenHolder2=(strLine);
                            StringTokenizer st2 = new StringTokenizer(HMMERTokenHolder2);
                            HMMERTargetNameToken2=st2.nextToken();
                            pfam_idToken2forCheck=st2.nextToken();
                            HMMERtlentoken2=st2.nextToken();
                            HMMERQueryProtIDToken2=st2.nextToken();
                            pfam_idToken2=st2.nextToken();
                            HMMERqlentoken2=st2.nextToken();
                            HMMERFullSeqEvalue2=st2.nextToken();
                            HMMERFullSeqscoretoken2=st2.nextToken();
                            Double HMMERFullSeqScore  = new Double(HMMERFullSeqscoretoken2);
                            HMMERFullSeqbiastoken2=st2.nextToken();
                            HMMERThisDomainPoundToken2=st2.nextToken();
                            HMMERThisDomainofToken2=st2.nextToken();
                            HMMERThisDomaincEvalueToken2=st2.nextToken();
                            HMMERThisDomainiEvaluetoken2=st2.nextToken();
                            HMMERThisDomainscoreToken2=st2.nextToken();
                            Double HMMERThisDomainSeqScore  = new Double(HMMERThisDomainscoreToken2);
                            
                            
                            HMMERThisbiasToken2=st2.nextToken();
                            HMMERhmmcoordfromToken2=st2.nextToken();
                            HMMERhmmcoordtoToken2=st2.nextToken();
                            HMMERalicoordfromToken2=st2.nextToken();
                            HMMERalicordtoToken2=st2.nextToken();
                            HMMERenvcordfromToken2=st2.nextToken();
                            HMMERenvcordtoToken2=st2.nextToken();
                            HMMERaccToken2=st2.nextToken();
                            HMMERTargetDescriptiontoken2=st2.nextToken();
                            DomainEnvolope2= HMMERenvcordfromToken2 + ":" + HMMERenvcordtoToken2;  
                            
                            while (st2.hasMoreTokens())
                                {
                                    String TempTokenHolder2=st2.nextToken();
                                    HMMERTargetDescriptiontoken2=HMMERTargetDescriptiontoken2+" "+TempTokenHolder2;
                                }
                            
                            
                            
                            prep.setString(1,HMMERQueryProtIDToken2);
                            prep.setString(2,pfam_idToken2forCheck);
                            prep.setString(3,HMMERTargetNameToken2);
                            prep.setString(4,HMMERTargetDescriptiontoken2);
                            prep.setString(5,HMMERalicoordfromToken2);
                            prep.setString(6,HMMERalicordtoToken2);
                            prep.setString(7,HMMERhmmcoordfromToken2);
                            prep.setString(8,HMMERhmmcoordtoToken2);
                            prep.setString(9,HMMERFullSeqEvalue2);
                            prep.setString(10,HMMERThisDomainiEvaluetoken2);
                            prep.setString(11,HMMERFullSeqscoretoken2);
                            prep.setString(12,HMMERThisDomainscoreToken2);
                            
                            
                            
                            
                            
                            
                            //add to dbaseopenstatmenttags
                            prep.addBatch();
                            CompletedModels[HeapArrayCounter] =ModelHeap;
                            HeapArrayCounter++;
                            CompletedModels[HeapArrayCounter]=Spacer;
                            HeapArrayCounter++;
                            ModelHeap = " ";
                            NumberofDomainsFound =1;
                            ModelHeap= ModelHeap + HMMERQueryProtIDToken2  + "  " + HMMERTargetNameToken2 + "  " + HMMERTargetDescriptiontoken2 + "<DomainEnvolope:" + DomainEnvolope2 + ">" + "<FullSeqeunce Evalue:"+HMMERFullSeqEvalue2 +">" + "<This Domain Evalue:" +  HMMERThisDomainiEvaluetoken2 +">" +"<PerSequnece Score:"  + HMMERFullSeqscoretoken2 + "|PerDomain Score:" + HMMERThisDomainscoreToken2 +">" + "<" + GASeqHolder +"|" + GADOMHolder +"|" + NoisePerSeqHolder + "|" + NoisePerDommainHolder + "|" + TrustedPerSeqHolder + "|" + TrustedPerDomHolder  + ">" + "<" + ThisSequneceGatheredValue+"|" + ThisDomainGatheredValue +"|" + ThisSequneceNoiseValue+ "|" + ThisDomainNoiseValue+ "|" + ThisSequneceTrustedValue+ "|" + ThisDomainTrustedValue + ">" + "|||||||";
                            HMMERTargetDescriptiontoken2="";
                            HMMERQueryProtIDToken=HMMERQueryProtIDToken2;
                            
                        }
                    
                    else 
                        {
                            CompletedModels[HeapArrayCounter] =ModelHeap;
                            HeapArrayCounter++;
                            i=LineCounter+2;
                        }
                    
                }
            
            conn.setAutoCommit(false);
            prep.executeBatch();
            conn.setAutoCommit(true);
            //print statment
            if (ToPrint.equals(PrintSent))
                {
                    ResultSet rs = stat.executeQuery("select * from HMMERDbase;");
                    while (rs.next()) {
                        System.out.println("QueryProtID = " + rs.getString("QueryProtID"));
                        System.out.println("pfam_id = " + rs.getString("pfam_id"));
                        System.out.println("HMMERDomain = " + rs.getString("HMMERDomain"));
                        System.out.println("HMMERTDomainDescription = " + rs.getString("HMMERTDomainDescription"));
                        System.out.println("QueryStartAlign = " + rs.getString("QueryStartAlign"));
                        System.out.println("QueryEndAlign = " + rs.getString("QueryEndAlign"));
                        System.out.println("PFAMStartAlign = " + rs.getString("PFAMStartAlign"));
                        System.out.println("PFAMEndAlign = " + rs.getString("PFAMEndAlign"));
                        System.out.println("FullSeqEvalue = " + rs.getString("FullSeqEvalue"));
                        System.out.println("ThisDomainEvalue = " + rs.getString("ThisDomainEvalue"));
                        System.out.println("FullSeqScore = " + rs.getString("FullSeqScore"));
                        System.out.println("FullDomainScore = " + rs.getString("FullDomainScore"));
                    }
                }
            //Close the input stream
            in.close();
            
            conn.close();
            
            System.out.println("Done.");
            System.exit(0);
            
            
            
        }catch (Exception e){//Catch exception if any
            //System.err.println("Error: " + e.getMessage() + " " + e.printStackTrace());
            e.printStackTrace();
            System.exit(1);
        }
    }
}
