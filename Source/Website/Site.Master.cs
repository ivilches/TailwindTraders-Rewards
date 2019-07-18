using System;
using System.Configuration;
using System.IO;
using System.Text;
using System.Web.UI;

namespace Tailwind.Traders.Rewards.Web
{
    public partial class SiteMaster : MasterPage
    {
        protected void Page_Load(object sender, EventArgs e)
        {
        }

        protected override void Render(HtmlTextWriter writer)
        {
            StringBuilder pageSource = new StringBuilder();
            StringWriter sw = new StringWriter(pageSource);
            HtmlTextWriter htmlWriter = new HtmlTextWriter(sw);
            base.Render(htmlWriter);

            //Run replacements
            RunPageReplacements(pageSource);

            //Output replacements
            writer.Write(pageSource.ToString());
        }

        private void RunPageReplacements(StringBuilder pageSource)
        {
            var baseUrl = Environment.GetEnvironmentVariable("BaseUrl");
            if (string.IsNullOrEmpty(baseUrl))
                baseUrl = ConfigurationManager.AppSettings["BaseUrl"];

            pageSource.Replace("[$BASE_URL]", baseUrl.TrimEnd('/'));
        }
    }
}